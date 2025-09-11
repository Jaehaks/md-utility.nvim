local M = {}

local LinePicker = require('md-utility.link_picker')
local Config = require('md-utility.config')

M.link_picker = function(mode)
	LinePicker.link_picker(mode)
end

M.get_config = function()
	Config.get()
end



return M
