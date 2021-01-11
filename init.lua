Nightshift = require('nightshift')
box.cfg {listen = 3311, log_level = 6}
Nightshift.start(function() return require 'config' end)
