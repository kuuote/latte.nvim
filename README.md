This project is work in progress.

simple template plugin, inspired by sonictemplate and tsnip.nvim

```lua
-- example mapping for test
vim.keymap.set({'n', 'i'}, '<C-y>', function()
  require('latte').open('function')
end)
```
