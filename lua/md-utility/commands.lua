local M = {}

local FilePicker = require('md-utility.file_picker')
local Paste = require('md-utility.paste')
local Config = require('md-utility.config')
local Autolist = require('md-utility.autolist')

M.file_picker = function(mode)
	FilePicker.file_picker(mode)
end

M.get_config = function()
	return Config.get()
end

M.clipboard_paste = function(style)
	Paste.ClipboardPaste(style)
end

M.autolist_cr_raw = function (show_marker)
	return Autolist.autolist_cr(show_marker)
end

M.autolist_o_raw = function (show_marker)
	return Autolist.autolist_o(show_marker)
end

M.autolist_tab_raw = function (reverse)
	return Autolist.autolist_tab(reverse)
end

M.autolist_recalculate = function ()
	return Autolist.autolist_recalculate()
end

-- wrapper to easy use for autolist_cr_raw
M.autolist_cr = function (show_marker)
	local autolist_cr = M.autolist_cr_raw(show_marker)
	if not autolist_cr then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
	end
end

-- wrapper to easy use for autolist_o_raw
M.autolist_o = function (show_marker)
	local autolist_o = M.autolist_o_raw(show_marker)
	if not autolist_o then
		vim.api.nvim_feedkeys('o', "n", false)
	end
end

-- wrapper to easy use for autolist_tab_raw
M.autolist_tab = function (reverse)
	local autolist_tab = M.autolist_tab_raw(reverse)
	if not autolist_tab then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<TAB>", true, false, true), "n", false)
	end
end


return M
