return {
  render = function(params)
    return string.format(
      [[
%sfunction%s(%s)
	%s
end
]],
      params.is_local and 'local ' or '',
      params.name == '' and '' or ' ' .. params.name,
      params.args,
      require('latte').get_cursor_marker()
    )
  end,
  params = [[
return {
  is_local = false,
  name = '',
  args = '',
}
]],
}
