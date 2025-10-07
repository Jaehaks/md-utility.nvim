local M = {}

M.setup = function(opts)
	require("md-utility.config").set(opts)
	require("md-utility.utils").check_cmd('rg')
	require("md-utility.highlights").init_highlights()
end

setmetatable(M, {
	__index = function(t, k)
		local commands = require('md-utility.commands')
		setmetatable(t, {__index = commands})
		return commands[k]
	end
})

return M
