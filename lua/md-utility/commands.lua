local M = {}

local FilePicker = require('md-utility.file_picker')
local Paste = require('md-utility.paste')
local Config = require('md-utility.config')

M.file_picker = function(mode)
	FilePicker.file_picker(mode)
end

M.get_config = function()
	Config.get()
end

M.clipboard_paste = function(style)
	Paste.ClipboardPaste(style)
end



return M
