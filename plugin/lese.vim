if exists('g:loaded_lese')
  finish
endif
let g:loaded_lese = 1

" Vim runs the Lua side only when it was built with it.
if !has('nvim') && !has('lua')
  echohl WarningMsg
  echomsg '[lese] Vim must be built with +lua'
  echohl None
  finish
endif
