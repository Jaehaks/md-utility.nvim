# md-utility.nvim
A collection of useful utilities in markdown

# Why?
It is just small functions to use in markdown for efficient editing because there are not plugins to meet my purpose.
I use [marksman](https://github.com/artempyanykh/marksman) for markdown lsp and make auxiliary tools to assist.

I will continue to add features whenever I think it's necessary


# requirements
- Markdown lsp : I use [marksman](https://github.com/artempyanykh/marksman) But it doesn't matter if you use something else.
- [Snacks.nvim](https://github.com/folke/snacks.nvim) : picker
- [Neovim v0.11+](https://github.com/neovim/neovim)
- [ripgrep](https://github.com/BurntSushi/ripgrep) : for link_picker


# Installation

If you use `lazy.nvim`

```lua
return {
  'Jaehaks/md-utility.nvim',
  ft = {'markdown'},
  opts = {

  }
}
```


# Configuration
- configuration of `marksman`
	- This plugin use `root_dir` of lsp, so It would recommends to set keymaps in lsp configuration
```lua
vim.lsp.config('marksman', {
  on_attach = function ()
    -- add keymaps in here
  end,
  cmd = {'marksman', 'server'},
  filetypes = {'markdown'},
  root_dir = '<what you want>',
})
```

- Default configuration of `md-utility` is like this.
```lua
require('md-utility').setup({
  link_picker = {
    ignore = {
      '.git/',
      'node_modules/',
      '.obsidian/',
      '.marksman.toml',
    }
  }
})
```



# API

## 1) `link_picker()`

### Purpose

There are many plugins or lsps that supports builtin completion to add link.
These are some shortcomings to use for me.
Some support nvim-cmp or blink-cmp only, or doesn't support non-english filepath or filename in link.
Some show completion menu but trigger timing is weird If you use non-english file.
Some can only `.md` files in link completion menu not all files in project.
Some inject link from completion using absolute path that is annoying.
Sometimes I cannot find links without visiting the file when I forgot the heading of the file.

These came across as inconvenient things to me. So I made this picker.
`marksman`'s `vim.lsp.buf.definition()` is very reliable, you can found any files regardless of path in link format.
I removed `lsp` source from `blink.cmp` after applying this.

### settings

```lua
-- link_picker()
vim.keymap.set({'n', 'i'}, '<M-e>', function()
  -- arguments can accepts two, 'markdown'|'wkik'
  -- These are link style if you insert link using <C-l> from picker.
  require('md-utility').link_picker('markdown')
end, {buffer = true, desc = 'show linklist'})
```

### demo




