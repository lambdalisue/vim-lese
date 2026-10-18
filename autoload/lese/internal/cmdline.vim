" Read the query with input(), starting from {text}. Returns v:null when the
" user cancels, so an empty query and a cancel stay apart.
function! lese#internal#cmdline#input(text) abort
  let s:text = a:text
  let s:aborted = 1
  augroup lese_internal_cmdline
    autocmd!
    autocmd CmdlineEnter * ++once call setcmdline(s:text)
    autocmd CmdlineLeave * ++once let s:aborted = v:event.abort
  augroup END
  try
    let l:result = input('')
  catch /^Vim:Interrupt$/
    return v:null
  finally
    augroup lese_internal_cmdline
      autocmd!
    augroup END
  endtry
  return s:aborted ? v:null : l:result
endfunction

" The text input() is reading and the cursor's byte position in it, or v:null
" when input() is not reading (Ex mode counts as the command line for mode()).
function! lese#internal#cmdline#state() abort
  if getcmdtype() !=# '@'
    return v:null
  endif
  return [getcmdline(), getcmdpos()]
endfunction

function! lese#internal#cmdline#set(text) abort
  if getcmdtype() ==# '@'
    call setcmdline(a:text)
  endif
endfunction

function! lese#internal#cmdline#accept() abort
  if getcmdtype() ==# '@'
    call feedkeys("\<CR>", 'n')
  endif
endfunction

function! lese#internal#cmdline#cancel() abort
  if getcmdtype() ==# '@'
    call feedkeys("\<Esc>", 'n')
  endif
endfunction
