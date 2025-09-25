local M = {}

local FilePicker = require('md-utility.file_picker')
local Paste = require('md-utility.paste')
local Config = require('md-utility.config')
local Autolist = require('md-utility.autolist')

M.file_picker = function(mode)
	FilePicker.file_picker(mode)
end

M.get_config = function()
	Config.get()
end

M.clipboard_paste = function(style)
	Paste.ClipboardPaste(style)
end

M.autolist_cr = function (show_marker)
	Autolist.autolist_cr(show_marker)
end

M.autolist_o = function (show_marker)
	Autolist.autolist_o(show_marker)
end


return M
