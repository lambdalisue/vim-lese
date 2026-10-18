if exists('g:loaded_lese_highlight')
  finish
endif
let g:loaded_lese_highlight = 1

function! s:init() abort
  if has('nvim')
    highlight default link LeseNormal NormalFloat
    highlight default link LeseBorder FloatBorder
  else
    highlight default link LeseNormal Normal
    highlight default link LeseBorder Delimiter
  endif

  " Input
  highlight default link LeseInputHeader LeseBorder
  highlight default link LeseInputCounter LeseBorder
  highlight default link LeseInputCursor Cursor

  " List
  highlight default link LeseListMatch Search
  highlight default link LeseListSelected CurSearch
  sign define LeseListSelectedSign text=≫ texthl=LeseListSelected

  " Help
  highlight default link LeseHelpHeader Conceal
  highlight default link LeseHelpMappingLhs Special
  highlight default link LeseHelpMappingRhs Title
  highlight default link LeseHelpMappingOperator Operator
endfunction

augroup lese_plugin_highlight
  autocmd!
  autocmd ColorScheme * call s:init()
augroup END

call s:init()
