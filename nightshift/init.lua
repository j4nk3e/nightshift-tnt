require 'pl'
local http_client = require('http.client')
local json = require('json')
local fiber = require('fiber')
local log = require('log')

local ns = {}

function ns.init()
    box.once("bootstrap", function()
        box.schema.space.create('nightshift', {
            format = {
                {name = 'id', type = 'unsigned'},
                {name = 'success', type = 'boolean'},
                {name = 'duration', type = 'double'},
                {name = 'time', type = 'double'}
            }
        })
        box.space.nightshift:create_index('primary', {
            type = 'TREE',
            parts = {1, 'unsigned'}
        })
    end)
end

function ns.handler(self)
    local data = box.space.nightshift.index.primary:max()
    return self:render{
        json = {
            success = data.success,
            duration_us = data.duration,
            time_us = data.time
        }
    }
end

local Monitor = {}
local Monitor_mt = {__index = Monitor}
setmetatable(Monitor, {
    __call = function(_, name, host, interval_ms, threshold_ms, channels)
        return setmetatable({
            name = name,
            host = host,
            interval = interval_ms / 1000,
            threshold = threshold_ms,
            channels = channels
        }, Monitor_mt)
    end
})

function Monitor:check()
    log.verbose('Running check to ' .. self.host)
    local timestamp_ms = tonumber(fiber.time64()) / 1000
    local start = fiber.clock64()
    local r = http_client.get(self.host, {timeout = self.threshold / 1000})
    local duration_ms = tonumber(fiber.clock64() - start) / 1000
    log.verbose('Check result for %s: %s in %dms', self.name, r.status,
                duration_ms)
    return r.status == 200 and duration_ms < self.threshold, duration_ms,
           timestamp_ms, r.status
end

function Monitor:alert(ok, duration, raw)
    for _, url in pairs(self.channels) do
        http_client.post(url, json.encode {
            text = string.format('%s ' .. (ok and '' or 'un') ..
                                     'healthy: status %s after %i ms',
                                 self.name, raw, duration)
        })
    end
end

function Monitor:loop()
    self.alerting = false
    while true do
        local ok, duration, timestamp, raw = self:check()
        if not ok and not self.alerting then
            log.warn(json.encode {
                text = string.format('%s unhealthy: status %s after %i ms',
                                     self.name, raw, duration)
            })
            self:alert(ok, duration, raw)
        elseif ok and self.alerting then
            log.warn(json.encode {
                text = string.format('%s healthy: status %s after %i ms',
                                     self.name, raw, duration)
            })
            self:alert(ok, duration, raw)
        end
        self.alerting = not ok
        box.space.nightshift:auto_increment{ok, duration, timestamp}
        fiber.sleep(self.interval)
    end
end

function ns.start(config)
    ns.init()
    local c = config()
    local server = require('http.server').new(c.api.host, c.api.port)
    local router = require('http.router').new({charset = "utf8"})
    server:set_router(router)
    router:route({path = '/'}, ns.handler)
    server:start()

    for name, monitor in pairs(c.monitors) do
        local m = Monitor(name, monitor.host, monitor.interval_ms or 5000,
                          monitor.threshold_ms or 1500, tablex.map(
                              function(it) return c.channels[it] end,
                              monitor.alert))
        fiber.create(function()
            log.info('Watching ' .. name .. ' at ' .. m.host)
            m:loop()
        end)
    end
end

return ns

