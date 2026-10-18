" The lua/ directories of lese and of every lese-* extension on
" 'runtimepath', after those in the optional {base} list, each once.
function! lese#luals#library(...) abort
  return luaeval('require("lese.host").export(require("lese.luals").library(require("lese.host").import(_A)))', a:0 ? a:1 : [])
endfunction
