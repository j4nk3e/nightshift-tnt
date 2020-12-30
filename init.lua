nightshift = require('nightshift')
box.cfg {listen = 3311, log_level = 6}
nightshift.start(function() return require 'config' end)
