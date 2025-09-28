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
  },
  autolist = {
    patterns = {
      bullet = "[-+*>]",
      digit = "%d+[.)]", -- 1. 1)
    },
    -- if user enter <CR> in list with empty content, remove the list and go to next line
    autoremove_cr = true,
    -- if user enter <TAB>, it guesses marker shape depends on adjacent usage.
    autoguess_tab = true,
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


## 3) `autolist`

### Purpose

It is inspired from [gaoDean/autolist.nvim](https://github.com/gaoDean/autolist.nvim) which is not managed now.
It has some bugs to I use, so reconstruct to meet what I needs

### Usages

Markdown considers `(-, *, +)` as bullets and `1)`, `1.` as numbered list only.
To convenient edit quotes, add `>` to autolist bullets as default.

#### 1) `autolist_cr(show_marker)`
If current line has bullets when you enter `<CR>`, the same marker is added to next line. \
If you enter `<CR>` with empty contents marker like `1) |`, (`|` is cursor position). \
The marker will be removed and go to next line if you set `autolist.autoremove_cr = true`.

`show_marker` argument is true as default. If false, cursor go to next line without marker.
But It add indentation which is same with upper line. See this example.

```markdown
<!-- before -->
1) test |

<!-- after -->
1) test
   |

```

Many terminal doesn't distinguish betwwen `<S-CR>` and `<CR>` so I prefer to use `<M-CR>`.

#### 2) `autolist_o(show_marker)`
It is similar with `autolist_cr()`. but 'o' motion.

#### 3) `autolist_tab(reverse)`
If `autoguess_tab = false`, it just indents by `vim.o.shiftwidth` with remaining current marker. \
If `autoguess_tab = true`, It detects adjacent list style and follow it. \
First, it detects most closed marker shape in inner scope of the parent marker,
if there are not, it found in outer scope. Fallback is current marker shape.

See demo.

#### 4) `autolist_recalculate()`

Auto-recalculating of markers when list are deleted is not implemented intentionally. I think it will be annoying.
Instead of, using `recalculate()` is more reliable.

It recalculates same indented markers. If the marker type is bullet, it unify all markers.
If the marker type is digit, it reorders the numbering with ascending from the number under cursor.

### settings

These are setting examples using wrapper function to deal with fallback.
If the line is not condition to execute autolist, it fallback to default key behavior
```lua
-- autolist <CR>
vim.keymap.set({'i'}, '<CR>', 	function()
  ---@param show_marker boolean
  require('md-utility').autolist_cr(true)
end,  {buffer = true, noremap = true, desc = '<CR> with autolist mark'})

-- without autolist <M-CR>
vim.keymap.set({'i'}, '<M-CR>', function()
  ---@param show_marker boolean
  require('md-utility').autolist_cr(false)
end, {buffer = true, noremap = true, desc = '<CR> without autolist mark but add indent'})

-- autolist o
vim.keymap.set({'n'}, 'o', 	function()
  ---@param show_marker boolean
  require('md-utility').autolist_o(true)
end,  {buffer = true, noremap = true, desc = '"o" with autolist mark'})

-- autolist tab
vim.keymap.set({'i'}, '<TAB>', 	function()
  ---@param reverse boolean
  require('md-utility').autolist_tab(false)
end,  {buffer = true, noremap = true, desc = '<TAB> with autolist mark'})

-- reverse autolist tab
vim.keymap.set({'i'}, '<S-TAB>', function()
  ---@param reverse boolean
  require('md-utility').autolist_tab(true)
end,  {buffer = true, noremap = true, desc = '<S-TAB> with autolist mark'})

-- recalculate list markers
vim.keymap.set({'n'}, '<leader>mr', function()
  require('md-utility').autolist_recalculate()
end,  {buffer = true, noremap = true, desc = 'recalculate list numbering'})
```

If you want to customize keys in more detail, you can use `*_raw()` APIs like this
for `autolist_cr()`, `autolist_o()` and `autolist_tab()`.

```lua
M.autolist_cr = function (show_marker)
	local autolist_cr = M.autolist_cr_raw(show_marker)
	-- you can add other what you need.
	if not autolist_cr then -- if autolist_cr_raw() isn't executed, return false
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
	end
end
```

### demo
https://github.com/user-attachments/assets/5586afd9-48fe-4058-a8f6-1c98fead9c39




