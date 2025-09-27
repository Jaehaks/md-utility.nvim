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
---@field lnum number line number of this information

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
				lnum = lnum,
			}
		end
	end
	return nil
end

-- get markers of next line
---@param bulletinfo autolist.bulletinfo
---@return string marker which will be used in next line
local function get_marker_on_cr(bulletinfo)
	if bulletinfo.type == 'bullet' then
		return bulletinfo.marker .. ' '
	elseif bulletinfo.type == 'digit' then
		return tostring(bulletinfo.number + 1) .. bulletinfo.punct .. ' '
	end
	return ''
end

-- get markers when tab input
-- It detects marker which is in similar indented line to unify list structure
---@param bulletinfo autolist.bulletinfo
---@param target_indent number
---@return string marker which will be used in next line
local function get_marker_on_tab(bulletinfo, target_indent)

	-- as default, remain current marker style
	local marker = bulletinfo.marker
	if bulletinfo.type == 'digit' then
		marker = 1 .. bulletinfo.punct
	end

	-- use reference from other list

	---@param info autolist.bulletinfo
	---@param is_inner boolean
	---@param num_marker_offset number
	---@return string
	local function make_marker (info, is_inner, num_marker_offset)
		if info.type == 'digit' then
			local num = is_inner and (info.number + num_marker_offset) or 1
			return num .. info.punct .. ' '
		end
		return info.marker .. ' '
	end

	---@param start_line number
	---@param end_line number
	---@param step number
	---@param is_inner boolean
	---@return string|number|nil
	local function search_marker(start_line, end_line, step, is_inner)
		for lnum = start_line, end_line, step do
			local info = get_bulletinfo(lnum)
			if info then
				vim.print(lnum .. ' ' .. info.indent)
				if info.indent == target_indent then
					return make_marker(info, is_inner, -step)
				elseif is_inner and info.indent < target_indent then
					return step == -1 and (lnum - 1) or (lnum + 1)
				end
			end
		end
		return nil
	end

	local search_range = 50
	local lc = vim.api.nvim_buf_line_count(0)

	-- Search upwards (inner scope)
	local result = search_marker(bulletinfo.lnum-1, math.max(1, bulletinfo.lnum - search_range), -1, true)
	if type(result) == 'string' then return result end
	local upper_lnum = result or 0

	-- Search downwards (inner scope)
	result = search_marker(bulletinfo.lnum+1, math.min(lc, bulletinfo.lnum + search_range), 1, true)
	if type(result) == 'string' then return result end
	local lower_lnum = result or 0

	-- Search upwards (outer scope)
	if upper_lnum > 0 then
		result = search_marker(upper_lnum, math.max(1, bulletinfo.lnum - search_range), -1, false)
		if type(result) == 'string' then return result end
	end

	-- Search downwards (outer scope)
	if lower_lnum > 0 then
		result = search_marker(lower_lnum, math.min(lc, bulletinfo.lnum + search_range), 1, false)
		if type(result) == 'string' then return result end
	end

	return marker .. ' '
end

-- check filetype of current buffer is possible to use autolist
---@return boolean
local function is_validft()
	return vim.tbl_contains({'markdown', 'text'}, vim.bo.filetype)
end

---############################################################################---
---## commands
---############################################################################---

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
	local next_marker = get_marker_on_cr(bulletinfo)
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

-- make autolist with o
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
	local next_marker = get_marker_on_cr(bulletinfo)
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
	vim.api.nvim_buf_set_lines(0, row, row, false, {
		next_line,
	})
	vim.api.nvim_win_set_cursor(0, {row+1, next_col})
	vim.cmd('startinsert!')

	return true
end

-- smart tab with modifying marker
M.autolist_tab = function(reverse)
	if not is_validft() then
		return false
	end

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local bulletinfo = get_bulletinfo(row)
	-- If cursor is not on start of line, return
	if not bulletinfo or (bulletinfo.content ~= bulletinfo.after) then
		return false
	end

	-- set next line marker
	reverse = (reverse == nil) and false or reverse
	local level = reverse and -vim.bo.shiftwidth or vim.bo.shiftwidth
	local tab_marker = get_marker_on_tab(bulletinfo, bulletinfo.indent + level)
	local cur_indent = Utils.create_indent(bulletinfo.indent + level)

	-- set next contents
	local cur_line = cur_indent .. tab_marker .. bulletinfo.after
	local next_col = #(cur_indent .. tab_marker)

	-- apply next contents
	vim.api.nvim_buf_set_lines(0, row-1, row, false, {
		cur_line,
	})
	vim.api.nvim_win_set_cursor(0, {row, next_col})

	return true
end

-- recalculate bullet / numbers
M.autolist_recalculate = function ()
	if not is_validft() then
		return false
	end

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local lc = vim.api.nvim_buf_line_count(0)
	local bulletinfo = get_bulletinfo(row)
	-- If cursor is not on start of line, return
	if not bulletinfo then
		return false
	end

	local start_num = bulletinfo.number
	local outscope = 0
	for lnum = row+1, lc do
		local info = get_bulletinfo(lnum)
		if info then
			if info.indent < bulletinfo.indent then -- if it meet upper list, it consider that the scope is end
				break
			end
			if info.indent == bulletinfo.indent then -- sublist is ignored
				-- change marker for same indent
				local cur_line = Utils.create_indent(info.indent)
				if bulletinfo.type == 'digit' then
					start_num = start_num + 1
					cur_line = cur_line .. start_num .. bulletinfo.punct .. ' ' .. info.content
				else
					cur_line = cur_line .. bulletinfo.marker .. ' ' .. info.content
				end
				vim.api.nvim_buf_set_lines(0, lnum-1, lnum, false, {
					cur_line,
				})
			end
			outscope = 0
		else
			-- This conditions are considered out of recalculation scope
			-- 1) if more than two empty lines are inserted continuously
			-- 2) non-bullet lines which has same indentation with current line are inserted
			local line = vim.api.nvim_buf_get_lines(0, lnum-1, lnum, false)[1]
			if line == '' or vim.fn.indent(lnum) == bulletinfo.indent then
				outscope = outscope + 1
			end
			if outscope > 1 then
				break
			end
		end
	end

	return true
end

return M
