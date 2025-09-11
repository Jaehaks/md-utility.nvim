local M = {}

local FilePicker = require('md-utility.file_picker')
local Config = require('md-utility.config')

M.file_picker = function(mode)
	FilePicker.file_picker(mode)
end

M.get_config = function()
	Config.get()
end



return M
