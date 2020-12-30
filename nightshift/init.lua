local http_client = require('http.client')
-- local json = require('json')
local fiber = require('fiber')
local log = require('log')

local ns = {interval = 5}

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

function ns.check(host)
    local timestamp_ms = tonumber(fiber.time64()) / 1000
    local start = fiber.clock64()
    local r = http_client.get(host)
    local duration_ms = tonumber(fiber.clock64() - start) / 1000
    log.info("Check result %s in %dms", r.status, duration_ms)
    return r.status ~= 200, duration_ms, timestamp_ms
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

function Monitor.new(host, interval)
    return setmetatable({host = host, interval = interval}, Monitor_mt)
end

function Monitor:loop()
    while true do
        local ok, time, t = ns.check(self.host)
        box.space.nightshift:auto_increment{ok, time, t}
        fiber.sleep(self.interval)
    end
end

function ns.start(config)
    ns.init()
    local server = require('http.server').new(nil, 8080)
    local router = require('http.router').new({charset = "utf8"})
    server:set_router(router)
    router:route({path = '/'}, ns.handler)
    server:start()

    for name, monitor in pairs(config.monitors) do
        local m = Monitor.new(monitor.host, monitor.interval_ms / 1000)
        fiber.create(function()
            log.info('Watching ' .. name)
            m:loop()
        end)
    end
end

return ns

