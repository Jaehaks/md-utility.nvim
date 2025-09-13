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

return M
