" Run the action {name} on the picker that is open, as if chosen from the
" action list. '@select' opens the action list.
function! lese#action(name) abort
  call lese#internal#dispatch(#{ type: 'action-invoke', name: a:name })
endfunction
