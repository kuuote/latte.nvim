---@class SavedState
---@field public mode string
---@field public cursor integer[]

local M = {}

local tmpl = {}

---@param filetype string
---@param force boolean
function M.load(filetype, force)
  if tmpl[filetype] ~= nil and not force then
    return
  end
  local t = {}
  tmpl[filetype] = t
  local path = vim.g['latte#path'] or vim.go.runtimepath
  local templates = vim.fn.globpath(path, 'latte/' .. filetype .. '/*.lua', false, true)
  for _, p in ipairs(templates) do
    t[vim.fn.fnamemodify(p, ':t:r')] = loadfile(p)()
  end
end

---@param name string
---@param force boolean
---@param state SavedState
function M.open(name, force, state)
  local mode = state and state.mode or vim.fn.mode()
  local cursor = state and state.cursor or vim.fn.getcurpos()
  table.remove(cursor, 1) -- remove unnecessary 0
  vim.cmd('stopinsert')

  local ft = vim.o.filetype
  M.load(ft, force)
  if not tmpl[ft][name] then
    error('template not found')
  end
  local template = tmpl[ft][name]

  local params_buf = vim.api.nvim_create_buf(false, true)
  local render_buf = vim.api.nvim_create_buf(false, true)

  local border = vim.tbl_map(function(c)
    return { c, 'Normal' }
  end, { '.', '.', '.', ':', ':', '.', ':', ':' })
  local row = math.floor(vim.go.lines / 8)
  local col = math.floor(vim.go.columns / 8)
  local height = math.floor(vim.go.lines - (vim.go.lines / 4))
  local width = math.floor(vim.go.columns - (vim.go.columns / 4))
  local halfwidth = math.floor(width / 2)

  local params_win = vim.api.nvim_open_win(params_buf, true, {
    relative = 'editor',
    border = border,
    row = row,
    col = col,
    height = height,
    width = halfwidth - 1,
  })
  local render_win = vim.api.nvim_open_win(render_buf, false, {
    relative = 'editor',
    border = border,
    row = row,
    col = col + halfwidth,
    height = height,
    width = halfwidth,
  })

  vim.api.nvim_buf_set_option(params_buf, 'filetype', 'lua')
  vim.api.nvim_win_set_option(params_win, 'winhighlight', 'NormalFloat:Normal')
  vim.api.nvim_win_set_option(render_win, 'winhighlight', 'NormalFloat:Normal')

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'TextChangedP' }, {
    buffer = params_buf,
    callback = function()
      local ok, result = pcall(function()
        local fn = loadstring(table.concat(vim.api.nvim_buf_get_lines(params_buf, 0, -1, false), '\n'))
        local params = fn()
        return template.render(params)
      end)
      if not ok then
        return
      end
      vim.api.nvim_buf_set_lines(render_buf, 0, -1, true, vim.split(result, '\n'))
    end,
  })

  vim.keymap.set('n', '<CR>', function()
    local result = vim.api.nvim_buf_get_lines(render_buf, 0, -1, false)
    vim.api.nvim_win_close(params_win, true)
    vim.api.nvim_win_close(render_win, true)
    if mode == 'i' then
      vim.cmd('startinsert')
      vim.fn.cursor(cursor)
      vim.g['latte#result'] = table.concat(result, '\n')
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<C-R>=g:latte#result<CR>', true, true, true), 'n')
    else
      vim.fn.append(vim.fn.line('.'), result)
      vim.cmd('normal! j^')
    end
  end, {
    buffer = params_buf,
  })

  vim.api.nvim_buf_set_lines(params_buf, 0, -1, true, vim.split(template.params, '\n'))
end

---@param force boolean
function M.find(force)
  ---@type SavedState
  local state = {
    mode = vim.fn.mode(),
    cursor = vim.fn.getcurpos(),
  }
  ---@type string
  local ft = vim.o.filetype
  M.load(ft, force)
  vim.ui.select(vim.tbl_keys(tmpl[ft]), {
    prompt = 'Select template',
  }, function(choice)
    if choice == nil then
      return
    end
    M.open(choice, false, state)
  end)
end

return M
