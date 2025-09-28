# md-utility.nvim
A collection of useful utilities in markdown

# Why?
It is just small functions to use in markdown for efficient editing because there are not plugins to meet my purpose.
I use [marksman](https://github.com/artempyanykh/marksman) for markdown lsp and make auxiliary tools to assist.

I will continue to add features whenever I think it's necessary


# requirements
- Markdown lsp : I use [marksman](https://github.com/artempyanykh/marksman) But it doesn't matter if you use something else.
- [Snacks.nvim](https://github.com/folke/snacks.nvim) : file_picker
- [Neovim v0.11+](https://github.com/neovim/neovim)
- [ripgrep](https://github.com/BurntSushi/ripgrep) : file_picker


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
  file_picker = {
    -- list to ignore when file_picker() list is shown.
	-- add '/' for directory, or it regards as file
    ignore = {
      '.git/',
      'node_modules/',
      '.obsidian/',
      '.marksman.toml',
    }
  },
  paste = {
    -- fun(ctx) : string
	-- function which returns path to paste clipboard image.
	-- ctx.root_dir : root directory of `marksman` lsp ends with slash by OS
	-- ctx.cur_dir : current buffer directory
	-- If you return directory, ask filename whenever you paste.
	-- If you return filepath, It will not ask. It is useful if you want to change filename automatically such as timer.
    image_path = function (ctx)
      return ctx.cur_dir
    end,
  }
})
```



# API

## 1) `file_picker()`

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

### Usages

This function can be used in both insert and normal mode.
`<CR>` is mapped to open `.md` file but it is not applied to other file like image/pdf etc..
`<C-l>` is mapped to make link to current cursor. It remains current mode (normal / insert) when you insert it.

> [!NOTE]
> Some options to customize will be added in the future.

### settings

```lua
-- file_picker()
vim.keymap.set({'n', 'i'}, '<M-e>', function()
  -- arguments can accepts one of them, 'markdown'|'wkik'
  -- These are link style if you insert link using <C-l> from picker.
  require('md-utility').file_picker('markdown')
end, {buffer = true, desc = 'show linklist'})
```

### demo

https://github.com/user-attachments/assets/368ca644-171f-4ec8-868e-de0a14466ba9


## 2) `clipboard_paste()`

### Purpose

It is useful if you want to make link to markdown file directly from system clipboard. \
I want that the behavior is changed by type of contents in clipboard.

### Usages

It supports three cases of file in clipboard. `clipboard_paste()` will judge the types and paste depends on it.

#### 1) Plain text
Paste the plain text.

#### 2) Web url (http:)
If the text is started with `http(s)` or `www.` \
<u>In normal mode,</u> It pastes in markdown/wiki link format without title. \
<u>In visual mode,</u> It pastes in markdown/wiki link format titled with visualized word. \
The link is not encoded to human-readable. There is no problem following link.

#### 3) Image
If the clipboard has image, It shows input prompt where you save it. \
The prompt is pre-filled with the result of `paste.image_path`. \

<u>If `image_path` is ended without extension,</u> it treats as directory and fill the folder path into the prompt.
You just enter the filename. If you input only filename, the image will be saved as `png` file or it follows extension you inputted. \
The clipboard image will be saved to file and link format will be inserted under cursor.

<u>If `image_path` is ended with extension</u>, it treats as file and don't ask where you save it.


### settings

```lua
-- clipboard_paste()
vim.keymap.set({'n', 'v'}, 'P', function()
  -- arguments can accepts one of them, 'markdown'|'wkik'
  require('md-utility').clipboard_paste('markdown')
end, {buffer = true, noremap = true, desc = 'Clipbaord paste'})
```

### demo
https://github.com/user-attachments/assets/9900805a-ef49-4fbe-b06a-963a2d80d595



