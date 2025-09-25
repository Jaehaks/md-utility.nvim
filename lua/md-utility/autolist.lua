local M = {}
local config = require('md-utility.config').get().autolist
local Utils = require('md-utility.utils')

---@class autolist.bulletinfo
---@field type string category of bullet
---@field indent number space indentation of the line
---@field content string contents string after marker
---@field marker string marker which means list pattern
---@field number number? number part of marker (digit type only)
---@field punct string? rest part of marker like '.', ')' (digit type only)
---@field before string contents before cursor in list line
---@field after string contents after cursor in list line

-- Parse list item and return components
---@param lnum number line number
---@return autolist.bulletinfo?
local function get_bulletinfo(lnum)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	lnum = lnum or row

	-- get line contents
	local line = vim.api.nvim_buf_get_lines(0, lnum-1, lnum, false)[1]
	local before = (lnum == row) and line:sub(1, col) or ''
	local after = (lnum == row) and line:sub(col+1) or ''

	for marker_type, pattern in pairs(config.patterns) do
		local capture_pattern = '^%s*(' .. pattern .. ')%s+(.*)'
		local marker, content = line:match(capture_pattern)
		if marker then
			return {
				type = marker_type,
				indent = vim.fn.indent(lnum),
				content = content,
				marker = marker,
				number = tonumber(marker:match('(%d+)')),
				punct = marker:match('%d+(.*)'),
				before = before,
				after = after,
			}
		end
	end
	return nil
end

-- get markers of next line
---@param bulletinfo autolist.bulletinfo
---@return string marker which will be used in next line
local function get_next_marker(bulletinfo)
	if bulletinfo.type == 'bullet' then
		return bulletinfo.marker .. ' '
	elseif bulletinfo.type == 'digit' then
		return tostring(bulletinfo.number + 1) .. bulletinfo.punct .. ' '
	end
	return ''
end

-- check filetype of current buffer is possible to use autolist
---@return boolean
local function is_validft()
	return vim.tbl_contains({'markdown', 'text'}, vim.bo.filetype)
end

-- make autolist
M.autolist_cr = function (show_marker)
	if not is_validft() then
		return false
	end

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local bulletinfo = get_bulletinfo(row)
	if not bulletinfo then
		return false
	end

	-- set next line marker
	show_marker = (show_marker == nil) and true or show_marker
	local next_marker = get_next_marker(bulletinfo)
	if not show_marker then
		next_marker = next_marker:gsub('.', ' ')
	end
	local prev_indent = Utils.create_indent(bulletinfo.indent)

	-- set next contents
	local cur_line  = bulletinfo.before
	local next_line = prev_indent .. next_marker .. bulletinfo.after
	local next_col  = #(prev_indent .. next_marker)
	if config.autoremove_cr and bulletinfo.content == '' then -- if content of list is empty, remove marker after <CR>
		cur_line  = prev_indent
		next_line = prev_indent
		next_col  = #prev_indent
	end

	-- apply next contents
	vim.api.nvim_buf_set_lines(0, row-1, row, false, {
		cur_line,
		next_line,
	})
	vim.api.nvim_win_set_cursor(0, {row+1, next_col})

	return true
end

M.autolist_o = function (show_marker)
	if not is_validft() then
		return false
	end

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local bulletinfo = get_bulletinfo(row)
	if not bulletinfo then
		return false
	end

	-- set next line marker
	show_marker = (show_marker == nil) and true or show_marker
	local next_marker = get_next_marker(bulletinfo)
	if not show_marker then
		next_marker = next_marker:gsub('.', ' ')
	end
	local prev_indent = Utils.create_indent(bulletinfo.indent)

	-- set next contents
	local next_line = prev_indent .. next_marker
	local next_col  = #(prev_indent .. next_marker)
	if config.autoremove_cr and bulletinfo.content == '' then -- if content of list is empty, remove marker after <CR>
		next_line = prev_indent
		next_col  = #prev_indent
	end

	-- apply next contents
	vim.api.nvim_buf_set_lines(0, row, row+1, false, {
		next_line,
	})
	vim.api.nvim_win_set_cursor(0, {row+1, next_col})
	vim.cmd('startinsert!')

	return true
end


return M
