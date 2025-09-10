local M = {}

-- change separator on directory depends on OS
---@param path string relative path
---@param sep_to string path separator after change
---@param sep_from string path separator before change
M.sep_unify = function(path, sep_to, sep_from)
	sep_to = sep_to or (vim.g.has_win32 and '\\' or '/')
	sep_from = sep_from or ((sep_to == '/') and '\\' or '/')
	return path:gsub(sep_from, sep_to)
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
---@param basedir string absolute path which is the base
---@param rootdir string absolute path which is project root
---@return string relative path of filepath
M.get_relative_path = function(filepath, basedir, rootdir)
	local path
	if filepath:sub(1, #basedir) == basedir then
		path = filepath:sub(#basedir + 2) -- remove leading [\\/]
	elseif filepath:sub(1, #rootdir) == rootdir then
		path = filepath:sub(#rootdir + 2)
	else
		path = filepath
	end
	return M.sep_unify(path, '/')
end

return M
