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

-- get root pattern of current file to check where is root directory
---@param bufnr integer buffer number
---@return string root directory
M.get_rootdir = function (bufnr)
	---@return vim.lsp.Client[]
	local clients = vim.lsp.get_clients({bufnr = bufnr}) -- check lsp is attached
	local root = ''
	if not vim.tbl_isempty(clients) then
		root = clients[1].config.root_dir
	else
		root = vim.fs.root(bufnr, {'.git', '.marksman.toml'}) or vim.fn.expand('%:p:h')
	end
	return root or vim.fn.expand('%:p:h')
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

-- check content is URL form like "https://*" or "www.*"
---@param content string web URL form
---@return string|nil
M.is_url = function(content)
	return (string.match(content, '^(https?://)')
			or string.match(content,'^(www%.)'))
end

-- check the filepath is image by extension
---@param path string any file path
---@return boolean
M.is_image = function(path)
	local image_exts = {'png', 'bmp', 'gif', 'svg', 'webp', 'jpg', 'jpeg', 'tiff', 'tif', 'row'}
	local file_ext = vim.fn.fnamemodify(path, ':e')
	return vim.tbl_contains(image_exts, file_ext)
end

-- check the filepath is markdown file
---@param path string any file path
---@return boolean
M.is_internalfile = function(path)
	-- check path is regarded internal heading of current buffer
	if string.match(path, '^#') then
		return true
	end

	-- check path is markdown file
	local file_ext = vim.fn.fnamemodify(path, ':e')
	if vim.tbl_contains({'md', 'markdown'}, file_ext) then
		return true
	elseif file_ext ~= '' then -- some other file
		return false
	end

	-- check the file is hidden file
	local filename = vim.fn.fnamemodify(path, ':t')
	if string.match(filename, '^%.') then
		return false
	end

	return true
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

-- get real end column number considering non-ASCII characters
---@param end_row number
---@param end_col number
---@return number
local get_real_endcol = function (end_row, end_col)
	local lines = vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)[1] -- get the line where end col is in.
	local end_bytecol = vim.str_utfindex(lines, 'utf-32', end_col) -- utf-8 means byte index, you use utf-32
	local real_end_col = end_col
	if end_bytecol then
		real_end_col = vim.str_byteindex(lines, 'utf-32', end_bytecol) -- get real end byte col of end character
	else
		vim.notify('Error(AddStrong) : end_bytecol is nil', vim.log.levels.ERROR)
	end
	return real_end_col
end

-- get index of visualized word, you need to check it is visual mode before it is executed.
---@return integer,integer,integer,integer
M.get_visualidx = function ()
	-- caution: getpos("'>") or getpos("'<") is updated after end of visual mode
	-- so use getpos('v') or getpos('.')

	local start_pos = vim.fn.getpos('v') -- get position of start of visual box
	local end_pos   = vim.fn.getpos('.') -- get position of end of visual box
	local start_row, start_col = start_pos[2], start_pos[3] -- byte unit, start column of start character
	local end_row, end_col     = end_pos[2], end_pos[3] -- byte unit, start column of end character

	-- it needs to get end column of end character as byte unit to perfect visualization.
	-- If there are non-ASCII characters, get the exact end col
	end_col = get_real_endcol(end_row, end_col)
	return start_row, start_col, end_row, end_col
end

-- check the argument path is absolute path
---@param path string
---@return boolean
M.is_AbsolutePath = function(path)
	if M.is_WinOS() then
		return path:match('^[%w]:[\\/]') ~= nil
	else
		return path:match('^/') ~= nil
	end
end


-- Create an indented white spaces, if 8, 8 spaces if expandtab, or 2 tabs if notexpandtab with 4 shift-width
---@param level integer the number of spaces to set indent before text
---@return string string includes indented characters
M.create_indent = function(level)
	level = level < 0 and 0 or level
	local indent_char = vim.bo.expandtab and ' ' or '\t'
	local indent_size = vim.bo.expandtab and level or level/vim.bo.shiftwidth
	return string.rep(indent_char, indent_size)
end

-- separate characters in [] pattern including escape
---@param pattern string
---@return string[] separated characters
M.sep_chars = function(pattern)
	local chars = {}
	local i = 1
	while i <= #pattern do
		if pattern:sub(i,i) == '%' and i < #pattern then
			table.insert(chars, pattern:sub(i, i+1))
			i = i + 2
		else
			table.insert(chars, pattern:sub(i, i))
			i = i + 1
		end
	end
	return chars
end

return M
