return {
  render = function(params)
    return string.format(
      [[
function %s(%s)
	%s
end]],
      params.name,
      params.args,
      require('latte').get_cursor_marker()
    )
  end,
  params = [[
return {
  name = '',
  args = '',
}
]],
}
