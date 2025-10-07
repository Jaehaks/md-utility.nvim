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
> [!CAUTION]
> You need to add `.marksman.toml` file in markdown project root to use proper lsp function.
> If you are using `obsidian` together, put `.marksman.toml` to the same directory where `.obsidian` is in.

- configuration of `marksman`
	- This plugin use `root_dir` of lsp, so It would recommends to set keymaps in lsp configuration.
```lua
vim.lsp.config('marksman', {
  on_attach = function ()
    -- add keymaps in here,
	-- or you can add keymaps in 'config' field of md-utility.nvim
  end,
  cmd = {'marksman', 'server'},
  filetypes = {'markdown'},
  root_marker = '.marksman.toml',
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
    },
	-- Insert title when link is inserted.
	-- When you insert external file link(not *.md file) using 'wiki', title will be removed although 'autotitle' is nil.
	-- nil : empty title
	-- filename : set filename as title only.
	-- full : set filename with relative path as title.
	autotitle = 'filename',
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
      bullet   = "[%-%+%*>]",      -- -, +, *, >
      digit    = "%d+[.)]",        -- 1. 1)
      checkbox = "-%s%[[x%-%s]%]", -- [x], [-], [ ]
    },
    autoremove_cr = true, -- if user enter <CR> in list with empty content, remove the list and go to next line
    autoguess_tab = true, -- if user enter <TAB>, it guesses marker shape depends on adjacent usage.
  },
  follow_link = {
      image_opener = 'start ""', -- image viewer command when the link under cursor is image.
      web_opener   = 'brave',    -- web browser command when the link under cursor is web link.
      md_opener    = 'split',    -- vim command when the link under cursor is file or header link.
      file_opener  = 'start ""', -- system command when the link under cursor is other file which is not image or md file
  }
})
```



# API

## 1) `file_picker(style)`

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

This function can be used in both insert and normal mode. \
`<CR>` is mapped to open `.md` file but it is not applied to other file like image/pdf etc.. \
`<C-l>` is mapped to make link to current cursor. It remains current mode (normal / insert) when you insert it.

If `style` is `markdown`, white space in file path or name will be encoded by `%20`. \
If `style` is `wiki`, white space is allowed in link so It is remained.
If the selected file is image file or other extension file not `*.md`, title isn't needed.
So `autotitle` field is ignored and title in link is empty.

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


## 2) `clipboard_paste(style)`

### Purpose

It is useful if you want to make link to markdown file directly from system clipboard. \
I want that the behavior is changed by type of contents in clipboard.

### Usages

It supports three cases of file in clipboard. `clipboard_paste()` will judge the types and paste depends on it. \
You can choose link format using `style` argument.

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

It is inspired from [gaoDean/autolist.nvim](https://github.com/gaoDean/autolist.nvim) which is not maintained now.
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

It recalculates same indented markers. If the marker type is bullet, it unify all markers. \
If the marker type is digit, it reorders the numbering with ascending from the number under cursor.

#### 5) `autolist_checkbox(step)`

If there is no bullet in current line, insert empty checkbox. \
If there is bullet which is not checkbox, replace the bullet with empty checkbox. \
If there is checkbox already, cycle through according on `autolist.checkbox` configuration.

`step` means cycle step and direction. It used checkbox change. \
If it is `1`, The checkbox will be changed to cycle in rightward direction in configuration.
If it is `-1`, The checkbox will be changed to cycle in leftward direction in configuration.

## 4) `addstrong`

### Purpose

To make convenient symbol insertion when you add some special symbols to highlight
such as `**`(asterisk), `__`(underscore), `<u></u>`(html underline) etc..

### Usages

1) Visualize some words.
2) executes the function.

#### 1) `addstrong(symbol)`

The `symbol` argument accepts `string` parameter which you want to insert both of side of visualized word. \
It considers that the visualized string is non-ASCII word also.

The keymap examples are here.

```lua
vim.keymap.set('v', '<leader>mb', function () md.addstrong('**') end, {buffer = true, desc = 'Enclose with **(bold)'})
vim.keymap.set('v', '<leader>mh', function () md.addstrong('==') end, {buffer = true, desc = 'Enclose with ==(highlight)'})
vim.keymap.set('v', '<leader>ms', function () md.addstrong('~~') end, {buffer = true, desc = 'Enclose with ~~(strikethrough)'})
vim.keymap.set('v', '<leader>mu', function () md.addstrong('<u>') end, {buffer = true, desc = 'Enclose with <u>(underline)'})
vim.keymap.set('v', '<leader>mm', function () md.addstrong('<mark>') end, {buffer = true, desc = 'Enclose with <mark>(mark highlight)'})
vim.keymap.set('v', '<leader>m=', function () md.addstrong('<sup>') end, {buffer = true, desc = 'Enclose with <sup>(sup highlight)'})
vim.keymap.set('v', '<leader>m-', function () md.addstrong('<sub>') end, {buffer = true, desc = 'Enclose with <sub>(sub highlight)'})
```

### demo

https://github.com/user-attachments/assets/ea08d978-98b0-408c-b03d-7f694b17c0cb


## 5) `link_picker()`

### Purpose

Open picker which shows all links(image, file, web) in current buffer.

### Usages

1) Open picker
2) If you select a link with `<CR>`, focus will move to the line.


```lua
vim.keymap.set('n', '<leader>ml', function () md.link_picker() end, {buffer = true, desc = 'Open link picker'})
```

### demo

See below demo

## 6) `follow_link()`

### Purpose

It is like smart version of `gf` in markdown file.

### Usages

Place your cursor over the link and run `follow_link()`.

1) If the link is <u>web url</u> (`https://` or `www.`), open browser using `web_opener` command.
2) If the link is <u>image</u>,  open image file using `image_opener` command. \
   It is useful on Windows If the terminal don't allowed preview feature. \
   Previewing in terminal which supports preview doesn't be implemented except of `wezterm` on Windows. \
   You can define the opener field using `function`.
3) If the link is <u>internal file</u> (`#heading`, `.md` or `.markdown`), open the file using `md_opener`. \
   It can move focus to the line. If `md_opener = nil`, file is opened in current focused window.
4) If the link is <u>external file</u> which is in other category open the file using `file_opener`.


```lua
vim.keymap.set('n', 'gf', function () md.follow_link() end, {buffer = true, desc = 'Follow link'})
```

### demo

https://github.com/user-attachments/assets/314dfb68-85b3-4dc5-91a0-b6d2e78cca3a




