function! lese#internal#picker#setup() abort
  call s:tolerant({ -> lese#internal#msgarea#hide() })
  call s:tolerant({ -> lese#internal#cursor#hide() })
  call lese#internal#mapping#store()
endfunction

function! lese#internal#picker#teardown() abort
  call s:tolerant({ -> lese#internal#msgarea#show() })
  call s:tolerant({ -> lese#internal#cursor#show() })
  call s:tolerant({ -> lese#internal#mapping#restore() })
endfunction

function! s:tolerant(callback) abort
  try
    call a:callback()
  catch
    if &verbose
      echohl WarningMsg
      echomsg printf('[lese] %s', v:exception)
      echohl None
    endif
  endtry
endfunction
