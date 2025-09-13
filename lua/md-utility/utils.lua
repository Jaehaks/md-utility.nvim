local M = {}

-- check OS
local WinOS = vim.fn.has('win32') == 1
M.is_WinOS = function()
	return WinOS
end

-- change separator on directory depends on OS
---@param path string relative path
---@param sep_to string? path separator after change
---@param sep_from string? path separator before change
---@param endslash boolean? add slash end of path or not
M.sep_unify = function(path, sep_to, sep_from, endslash)
	sep_to = sep_to or (WinOS and '\\' or '/')
	sep_from = sep_from or ((sep_to == '/') and '\\' or '/')
	local endchar = endslash and sep_to or ''
	return path:gsub('[/\\]+$', ''):gsub(sep_from, sep_to) .. endchar
end

---@param cmd string external command
M.check_cmd = function(cmd)
	if vim.fn.executable(cmd) == 1 then
		return true
	else
		vim.notify('md-utility : ' .. cmd .. ' is required but not installed!')
		return false
	end
end

-- get relative path based on basedir first. if not, rootdir. if not too, original file
---@param filepath string absolute path to make relative path
---@param basedir string absolute path which is the base, (it must ends with slash)
---@param rootdir string absolute path which is project root, (it must ends with slash)
---@return string relative path of filepath
M.get_relative_path = function(filepath, basedir, rootdir)
	local path
	if filepath:sub(1, #basedir) == basedir then
		path = filepath:sub(#basedir + 1)
	elseif filepath:sub(1, #rootdir) == rootdir then
		path = filepath:sub(#rootdir + 1)
	else
		path = filepath
	end
	return M.sep_unify(path, '/')
end

-- check the filepath is image by extension
---@param path string any file path
M.is_image = function(path)
	local image_exts = {'png', 'bmp', 'gif', 'svg', 'webp', 'jpg', 'jpeg', 'tiff', 'tif', 'row'}
	local file_ext = vim.fn.fnamemodify(path, ':e')
	return vim.tbl_contains(image_exts, file_ext)
end

-- return link format
---@param style string markdown|wiki
---@param link string contents of link
---@param title string? title of link
---@return string formatted link string
M.link_formatter = function(style, link, title)
	local format
	if style == 'markdown' then
		-- make image token
		local token = M.is_image(link) and '!' or ''
		title = title or ''
		format = token .. '[' .. title .. '](' .. link .. ')'
	elseif style == 'wiki' then
		title = title and '|' .. title or ''
		format = '[[' .. link .. title .. ']]'
	else
		vim.notify('set style correctly', vim.log.levels.ERROR)
		format = ''
	end
	return format
end

-- get index of visualized word, you need to check it is visual mode before it is executed.
---@return integer,integer,integer,integer
M.GetIdxVisual = function ()
	-- caution: getpos("'>") or getpos("'<") is updated after end of visual mode
	-- so use getpos('v') or getpos('.')

	local start_pos = vim.fn.getpos('v') -- get position of start of visual box
	local end_pos   = vim.fn.getpos('.') -- get position of end of visual box
	local start_row, start_col = start_pos[2], start_pos[3]
	local end_row, end_col     = end_pos[2], end_pos[3]

	-- check end col regardless of non-ASCII char
	local lines = vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)
	if lines[1] ~= '' then -- if it is not empty (normal mode)
		local end_bytecol = vim.str_utfindex(lines[1], 'utf-8', end_col)
		if end_bytecol then
			end_col = vim.str_byteindex(lines[1], 'utf-8', end_bytecol)
		else
			vim.notify('Error : end_bytecol is nil', vim.log.levels.ERROR)
		end
	end
	return start_row, start_col, end_row, end_col
end

M.is_AbsolutePath = function(path)
	if M.is_WinOS() then
		return path:match('^[%w]:[\\/]') ~= nil
	else
		return path:match('^/') ~= nil
	end
end

return M
