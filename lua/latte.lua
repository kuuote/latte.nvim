---@return string
local function get_cursor_marker()
  return '__latte_cursor__'
end

---@class SavedState
---@field public mode string
---@field public cursor integer[]

---@return SavedState
local function get_state()
  return {
    mode = vim.api.nvim_get_mode().mode,
    cursor = vim.api.nvim_win_get_cursor(0),
  }
end

---@param result string
---@param state SavedState
local function insert(result, state)
  local lines = vim.split(result, '\n')
  local save_virtualedit = vim.wo.virtualedit
  local save_reg = vim.fn.getreginfo('z')
  local marker = get_cursor_marker()
  local has_cursor = result:match(marker) ~= nil

  if state.mode == 'n' then
    vim.fn.setreg('z', lines, 'V')
    vim.cmd('normal! "z]p')
  elseif state.mode == 'i' then
    local indent = vim.api.nvim_get_current_line():match('^%s*')
    local indented = vim.list_extend(
      { lines[1] },
      vim.tbl_map(function(line)
        return indent .. line
      end, vim.list_slice(lines, 2))
    )
    vim.fn.setreg('z', indented, 'v')
    vim.wo.virtualedit = 'all'
    vim.api.nvim_win_set_cursor(0, state.cursor)
    vim.cmd('normal! "zgP')
    local line = state.cursor[1]
    vim.cmd(('%d,%dretab!'):format(line, line + #lines - 1))
  end
  if has_cursor then
    vim.fn.search(marker, 'b')
    vim.cmd('normal! "_d' .. #marker .. 'l')
  end
  if state.mode == 'i' then
    vim.cmd('startinsert')
  end

  vim.fn.setreg('z', save_reg)
  vim.wo.virtualedit = save_virtualedit
end

---@param template unknown
---@param params_text string
---@return boolean, string
local function render(template, params_text)
  local ok, result = pcall(function()
    local fn = loadstring(params_text)
    ---@diagnostic disable-next-line: need-check-nil
    local params = fn()
    return template.render(params)
  end)
  return ok, result
end

local M = {
  get_cursor_marker = get_cursor_marker,
}

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
---@param state SavedState | nil
function M.open(name, force, state)
  state = state or get_state()

  local ft = vim.bo.filetype
  M.load(ft, force)
  if not tmpl[ft][name] then
    error('template not found: ' .. name)
  end
  local template = tmpl[ft][name]

  local params_buf = vim.api.nvim_create_buf(false, true)
  local render_buf = vim.api.nvim_create_buf(false, true)

  local border = 'single'
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
  vim.api.nvim_win_set_option(params_win, 'winhighlight', 'NormalFloat:Normal,FloatBorder:Normal')
  vim.api.nvim_win_set_option(render_win, 'winhighlight', 'NormalFloat:Normal,FloatBorder:Normal')

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'TextChangedP' }, {
    buffer = params_buf,
    callback = function()
      local ok, result = render(template, table.concat(vim.api.nvim_buf_get_lines(params_buf, 0, -1, false), '\n'))
      if not ok then
        return
      end
      vim.api.nvim_buf_set_lines(render_buf, 0, -1, true, vim.split(result:gsub(get_cursor_marker(), '|'), '\n'))
    end,
  })

  vim.keymap.set('n', '<CR>', function()
    local ok, result = render(template, table.concat(vim.api.nvim_buf_get_lines(params_buf, 0, -1, false), '\n'))
    if not ok then
      vim.api.nvim_echo({ { 'params evaluation failed\n', 'ErrorMsg' }, { result, 'ErrorMsg' } }, true, {})
      return
    end
    vim.api.nvim_win_close(params_win, true)
    vim.api.nvim_win_close(render_win, true)
    insert(result, state)
  end, {
    buffer = params_buf,
  })

  vim.api.nvim_buf_set_lines(params_buf, 0, -1, true, vim.split(template.params, '\n'))
  vim.api.nvim_exec_autocmds('User', {
    pattern = 'latte#open',
    modeline = false,
  })
  vim.fn.timer_start(0, function()
    -- なぜか挿入モードが解除されないのでタイマーで発動
    vim.cmd('stopinsert')
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end)
end

---@param force boolean
function M.find(force)
  ---@type SavedState
  local state = get_state()
  ---@type string
  local ft = vim.bo.filetype
  M.load(ft, force)
  vim.ui.select(vim.tbl_keys(tmpl[ft]), {
    prompt = 'Select template',
  }, function(choice)
    if choice == nil then
      if state.mode == 'i' then
        vim.cmd('startinsert')
      end
      vim.api.nvim_win_set_cursor(0, state.cursor)
      return
    end
    M.open(choice, false, state)
  end)
end

return M
