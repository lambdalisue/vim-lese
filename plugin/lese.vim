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

let s:sep = has('win32') ? '\' : '/'

command! -nargs=+ -complete=customlist,lese#internal#command#complete
      \ Lese call lese#internal#command#call('lese', <q-args>)
command! -nargs=? -complete=customlist,lese#internal#command#complete_resume
      \ LeseResume call lese#internal#command#call('resume', <q-args>)
command! -nargs=0 LeseSession call lese#internal#command#call('session', '')
command! -nargs=0 LeseCustom call lese#internal#command#call('custom', '')
command! -nargs=0 LeseCustomReload call lese#internal#command#call('custom_reload', '')

function! s:bypass(event) abort
  let l:name = matchstr(expand('<amatch>'), '^.\+:\zs.*$')
  execute printf('doautocmd <nomodeline> User %s:%s', a:event, l:name)
endfunction

augroup lese_plugin
  autocmd! *
  autocmd User LesePickerEnter:* :
  autocmd User LesePickerLeave:* :
  autocmd User LeseCustomLoaded :
  autocmd User LesePreviewRendered:* :
  autocmd User LesePickerEnterSystem:* ++nested call s:bypass('LesePickerEnter')
  autocmd User LesePickerLeaveSystem:* ++nested call s:bypass('LesePickerLeave')
augroup END

if !exists('g:lese_custom_path')
  let g:lese_custom_path = has('nvim')
        \ ? expand(join([stdpath('config'), 'lese', 'custom.lua'], s:sep))
        \ : expand(join([$HOME, '.vim', 'lese', 'custom.lua'], s:sep))
endif
