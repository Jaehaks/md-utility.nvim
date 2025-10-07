local M = {}

M.init_highlights = function()
	vim.api.nvim_set_hl(0, 'MdUtilityLinkImage', {fg = '#E5C07B'})
	vim.api.nvim_set_hl(0, 'MdUtilityLinkWeb',   {fg = '#77A868'})
	vim.api.nvim_set_hl(0, 'MdUtilityLinkFile',  {fg = '#BD93F9'})
end

return M
