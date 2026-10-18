" Syntax highlight a preview buffer without running ftplugins.
function! lese#internal#highlight#fast(filetype) abort
  let l:eventignore_saved = &eventignore
  try
    set eventignore+=FileType
    call lese#internal#highlight#real(a:filetype)
  finally
    let &eventignore = l:eventignore_saved
  endtry
  silent! execute printf('runtime syntax/%s.vim', fnameescape(&filetype))
endfunction

function! lese#internal#highlight#real(filetype) abort
  if empty(a:filetype)
    silent! unlet! b:ftdetect
    silent! filetype detect
  else
    let &filetype = a:filetype
  endif
endfunction
