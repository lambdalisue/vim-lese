function! lese#internal#command#call(name, args) abort
  call luaeval('require("lese.command").call(_A[1], _A[2])', [a:name, a:args])
endfunction

function! lese#internal#command#complete(arglead, cmdline, cursorpos) abort
  return luaeval('require("lese.command").complete(_A[1], _A[2], _A[3])', [a:arglead, a:cmdline, a:cursorpos])
endfunction

function! lese#internal#command#complete_resume(arglead, cmdline, cursorpos) abort
  return luaeval('require("lese.command").complete_resume(_A[1], _A[2], _A[3])', [a:arglead, a:cmdline, a:cursorpos])
endfunction
