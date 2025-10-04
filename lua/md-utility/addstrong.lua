local M = {}

local Utils = require('md-utility.utils')

-- Add strong mark (**) both side of visualized region
---@param symbol string marks to add before and after visualized word (default is **)
M.AddStrong = function (symbol)
	-- check args is string
	if type(symbol) ~= 'string' then
		vim.notify('Error(AddStrong) : use string for args', vim.log.levels.ERROR)
		return
	end

	-- get index of visualized word
	-- ascii byte unit, end_col is column number where the end character ends
	local start_row, start_col, end_row, end_col = Utils.get_visualidx()

	local marks = symbol or '**' -- set start marks to add
	local marks_e = marks -- end marks, if html format, add / in marks
	local tag = marks:match('^<([^>]+)>$')
	if tag then
		marks_e = '</' .. tag .. '>'
	end

	-- Insert asterisks at the start of the selection
	vim.api.nvim_buf_set_text(0, start_row - 1, start_col - 1, start_row - 1, start_col - 1, {marks})
	if start_row == end_row then -- if 'marks' is added in same line, it must be considered
		end_col = end_col + #marks
	end

	-- Add asterisks at the end of the selection.
	-- use 'end_col' instead of 'and_col-1' because adding character is inserted next to end_col
	vim.api.nvim_buf_set_text(0, end_row - 1, end_col , end_row - 1, end_col, {marks_e})

	-- go to normal mode
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
end


return M
