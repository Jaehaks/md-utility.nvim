local M = {}

M.setup = function(opts)
	require("md-utility.config").set(opts)
	require("md-utility.utils").check_cmd('rg')

end

M.config = setmetatable({}, {
	__index = function(_, k)
		return require('md-utility.config')[k]
	end
})

return setmetatable(M, {
	__index = function(_, k)
		return require('md-utility.commands')[k]
	end
})
