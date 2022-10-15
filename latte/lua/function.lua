return {
  render = function(params)
    return string.format(
      [[
function %s(%s)
end]],
      params.name,
      params.args
    )
  end,
  params = [[
return {
  name = '',
  args = '',
}
]],
}
