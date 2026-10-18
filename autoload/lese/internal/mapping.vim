function! lese#internal#mapping#store() abort
  if exists('s:saved_maps')
    return
  endif
  let s:saved_maps = maplist()->filter({ _, m -> m.mode ==# 'c' || m.mode ==# '!' })
endfunction

" Restoring runs twice: a single pass leaves mappings that refer to each other
" (cnoremap <Up> <C-p> with cnoremap <C-p> <Up>) half restored.
function! lese#internal#mapping#restore() abort
  if !exists('s:saved_maps')
    return
  endif
  cmapclear
  call foreach(s:saved_maps, {_, m -> mapset(m)})
  call foreach(s:saved_maps, {_, m -> mapset(m)})
  unlet s:saved_maps
endfunction

" The command-line mappings that reach lese, as {lhs, rhs} pairs for the help.
function! lese#internal#mapping#list() abort
  return maplist()
        \->filter({ _, m -> m.mode ==# 'c' || m.mode ==# '!' })
        \->map({ _, m -> #{ lhs: m.lhs, rhs: m.rhs } })
endfunction
