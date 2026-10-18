if exists('g:loaded_lese_mapping')
  finish
endif
let g:loaded_lese_mapping = 1

function! s:dispatch(event) abort
  call lese#internal#dispatch(a:event)
endfunction

" List
cnoremap <silent> <Plug>(lese-list-first) <Cmd>call <SID>dispatch(#{type: 'move-cursor-at', cursor: 0})<CR>
cnoremap <silent> <Plug>(lese-list-last) <Cmd>call <SID>dispatch(#{type: 'move-cursor-at', cursor: '$'})<CR>
cnoremap <silent> <Plug>(lese-list-prev) <Cmd>call <SID>dispatch(#{type: 'move-cursor', amount: -1})<CR>
cnoremap <silent> <Plug>(lese-list-next) <Cmd>call <SID>dispatch(#{type: 'move-cursor', amount: 1})<CR>
cnoremap <silent> <Plug>(lese-list-prev:scroll) <Cmd>call <SID>dispatch(#{type: 'move-cursor', amount: -1, scroll: v:true})<CR>
cnoremap <silent> <Plug>(lese-list-next:scroll) <Cmd>call <SID>dispatch(#{type: 'move-cursor', amount: 1, scroll: v:true})<CR>
cnoremap <silent> <Plug>(lese-list-left) <Cmd>call <SID>dispatch(#{type: 'list-component-execute', command: 'silent! normal! zh'})<CR>
cnoremap <silent> <Plug>(lese-list-right) <Cmd>call <SID>dispatch(#{type: 'list-component-execute', command: 'silent! normal! zl'})<CR>
cnoremap <silent> <Plug>(lese-list-left:scroll) <Cmd>call <SID>dispatch(#{type: 'list-component-execute', command: 'silent! normal! zH'})<CR>
cnoremap <silent> <Plug>(lese-list-right:scroll) <Cmd>call <SID>dispatch(#{type: 'list-component-execute', command: 'silent! normal! zL'})<CR>

" Select
cnoremap <silent> <Plug>(lese-select) <Cmd>call <SID>dispatch(#{type: 'select-item'})<CR>
cnoremap <silent> <Plug>(lese-select-all) <Cmd>call <SID>dispatch(#{type: 'select-all-items'})<CR>

" Switch
cnoremap <silent> <Plug>(lese-switch-matcher-first) <Cmd>call <SID>dispatch(#{type: 'switch-matcher-at', index: 0})<CR>
cnoremap <silent> <Plug>(lese-switch-matcher-last) <Cmd>call <SID>dispatch(#{type: 'switch-matcher-at', index: '$'})<CR>
cnoremap <silent> <Plug>(lese-switch-matcher-prev) <Cmd>call <SID>dispatch(#{type: 'switch-matcher', amount: -1, cycle: v:true})<CR>
cnoremap <silent> <Plug>(lese-switch-matcher-next) <Cmd>call <SID>dispatch(#{type: 'switch-matcher', amount: 1, cycle: v:true})<CR>
cnoremap <silent> <Plug>(lese-switch-sorter-first) <Cmd>call <SID>dispatch(#{type: 'switch-sorter-at', index: 0})<CR>
cnoremap <silent> <Plug>(lese-switch-sorter-last) <Cmd>call <SID>dispatch(#{type: 'switch-sorter-at', index: '$'})<CR>
cnoremap <silent> <Plug>(lese-switch-sorter-prev) <Cmd>call <SID>dispatch(#{type: 'switch-sorter', amount: -1, cycle: v:true})<CR>
cnoremap <silent> <Plug>(lese-switch-sorter-next) <Cmd>call <SID>dispatch(#{type: 'switch-sorter', amount: 1, cycle: v:true})<CR>
cnoremap <silent> <Plug>(lese-switch-renderer-first) <Cmd>call <SID>dispatch(#{type: 'switch-renderer-at', index: 0})<CR>
cnoremap <silent> <Plug>(lese-switch-renderer-last) <Cmd>call <SID>dispatch(#{type: 'switch-renderer-at', index: '$'})<CR>
cnoremap <silent> <Plug>(lese-switch-renderer-prev) <Cmd>call <SID>dispatch(#{type: 'switch-renderer', amount: -1, cycle: v:true})<CR>
cnoremap <silent> <Plug>(lese-switch-renderer-next) <Cmd>call <SID>dispatch(#{type: 'switch-renderer', amount: 1, cycle: v:true})<CR>
cnoremap <silent> <Plug>(lese-switch-previewer-first) <Cmd>call <SID>dispatch(#{type: 'switch-previewer-at', index: 0})<CR>
cnoremap <silent> <Plug>(lese-switch-previewer-last) <Cmd>call <SID>dispatch(#{type: 'switch-previewer-at', index: '$'})<CR>
cnoremap <silent> <Plug>(lese-switch-previewer-prev) <Cmd>call <SID>dispatch(#{type: 'switch-previewer', amount: -1, cycle: v:true})<CR>
cnoremap <silent> <Plug>(lese-switch-previewer-next) <Cmd>call <SID>dispatch(#{type: 'switch-previewer', amount: 1, cycle: v:true})<CR>

" Preview
cnoremap <silent> <Plug>(lese-preview-first) <Cmd>call <SID>dispatch(#{type: 'preview-component-execute', command: 'silent! normal! gg'})<CR>
cnoremap <silent> <Plug>(lese-preview-last) <Cmd>call <SID>dispatch(#{type: 'preview-component-execute', command: 'silent! normal! G'})<CR>
cnoremap <silent> <Plug>(lese-preview-prev) <Cmd>call <SID>dispatch(#{type: 'preview-component-execute', command: 'silent! normal! k'})<CR>
cnoremap <silent> <Plug>(lese-preview-next) <Cmd>call <SID>dispatch(#{type: 'preview-component-execute', command: 'silent! normal! j'})<CR>
cnoremap <silent> <Plug>(lese-preview-prev:scroll) <Cmd>call <SID>dispatch(#{type: 'preview-component-execute', command: 'silent! normal! <C-u>'})<CR>
cnoremap <silent> <Plug>(lese-preview-next:scroll) <Cmd>call <SID>dispatch(#{type: 'preview-component-execute', command: 'silent! normal! <C-d>'})<CR>
cnoremap <silent> <Plug>(lese-preview-left) <Cmd>call <SID>dispatch(#{type: 'preview-component-execute', command: 'silent! normal! zh'})<CR>
cnoremap <silent> <Plug>(lese-preview-right) <Cmd>call <SID>dispatch(#{type: 'preview-component-execute', command: 'silent! normal! zl'})<CR>
cnoremap <silent> <Plug>(lese-preview-left:scroll) <Cmd>call <SID>dispatch(#{type: 'preview-component-execute', command: 'silent! normal! zH'})<CR>
cnoremap <silent> <Plug>(lese-preview-right:scroll) <Cmd>call <SID>dispatch(#{type: 'preview-component-execute', command: 'silent! normal! zL'})<CR>

" Help
cnoremap <silent> <Plug>(lese-help) <Cmd>call <SID>dispatch(#{type: 'help-component-toggle'})<CR>
cnoremap <silent> <Plug>(lese-help-prev) <Cmd>call <SID>dispatch(#{type: 'help-component-page', amount: -1})<CR>
cnoremap <silent> <Plug>(lese-help-next) <Cmd>call <SID>dispatch(#{type: 'help-component-page', amount: 1})<CR>

" Action
cnoremap <silent> <Plug>(lese-action-select) <Cmd>call lese#action('@select')<CR>

if !get(g:, 'lese#disable_default_mappings')
  function! s:define(lhs, rhs) abort
    execute 'cnoremap <silent> <nowait> ' .. a:lhs .. ' ' .. a:rhs
  endfunction

  function! s:map_picker() abort
    " List
    call s:define('<C-t>', '<Plug>(lese-list-first)')
    call s:define('<C-g>', '<Plug>(lese-list-last)')
    call s:define('<C-p>', '<Plug>(lese-list-prev)')
    call s:define('<C-n>', '<Plug>(lese-list-next)')
    call s:define('<C-u>', '<Plug>(lese-list-prev:scroll)')
    call s:define('<C-d>', '<Plug>(lese-list-next:scroll)')
    call s:define('<PageUp>', '<Plug>(lese-list-left)')
    call s:define('<PageDown>', '<Plug>(lese-list-right)')
    call s:define('<S-PageUp>', '<Plug>(lese-list-left:scroll)')
    call s:define('<S-PageDown>', '<Plug>(lese-list-right:scroll)')
    call s:define('<C-,>', '<Plug>(lese-select)')
    call s:define('<C-.>', '<Plug>(lese-select-all)')
    call s:define('<C-j>', '<Plug>(lese-select)<Plug>(lese-list-next)')
    call s:define('<C-k>', '<Plug>(lese-list-prev)<Plug>(lese-select)')
    " Preview
    call s:define('<Home>', '<Plug>(lese-preview-first)')
    call s:define('<End>', '<Plug>(lese-preview-last)')
    call s:define('<Up>', '<Plug>(lese-preview-prev)')
    call s:define('<Down>', '<Plug>(lese-preview-next)')
    call s:define('<S-Up>', '<Plug>(lese-preview-prev:scroll)')
    call s:define('<S-Down>', '<Plug>(lese-preview-next:scroll)')
    call s:define('<Left>', '<Plug>(lese-preview-left)')
    call s:define('<Right>', '<Plug>(lese-preview-right)')
    call s:define('<S-Left>', '<Plug>(lese-preview-left:scroll)')
    call s:define('<S-Right>', '<Plug>(lese-preview-right:scroll)')
    " Action
    call s:define('<Tab>', '<Plug>(lese-action-select)')
    call s:define('<C-x>', "<Cmd>call lese#action('open:split')<CR>")
    call s:define('<C-v>', "<Cmd>call lese#action('open:vsplit')<CR>")
    " Help
    call s:define('<F1>', '<Plug>(lese-help)')
    call s:define('<S-Home>', '<Plug>(lese-help-prev)')
    call s:define('<S-End>', '<Plug>(lese-help-next)')
    " Switch
    call s:define('<F2>', '<Plug>(lese-switch-matcher-next)')
    call s:define('<F3>', '<Plug>(lese-switch-sorter-next)')
    call s:define('<F4>', '<Plug>(lese-switch-renderer-next)')
    call s:define('<F5>', '<Plug>(lese-switch-previewer-next)')
  endfunction

  augroup lese_mapping_plugin
    autocmd!
    autocmd User LesePickerEnterSystem:* call s:map_picker()
  augroup END
endif
