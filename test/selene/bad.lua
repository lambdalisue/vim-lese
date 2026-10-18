-- A module that breaks the rule; `just lint` checks that selene/lese.yml rejects it.
return function()
  return vim.fn.getcwd()
end
