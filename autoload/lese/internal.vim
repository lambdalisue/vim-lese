" Call a Lua function registered with require('lese.host').register().
function! lese#internal#invoke(id, ...) abort
  return luaeval('require("lese.host").invoke(_A[1], _A[2])', [a:id, a:000])
endfunction

function! lese#internal#echomsg(message, highlight) abort
  execute 'echohl' a:highlight
  for l:line in split(a:message, "\n")
    echomsg l:line
  endfor
  echohl None
endfunction

" A job does not survive the trip to Lua on Vim (it arrives as nil), so jobs
" stay here and Lua holds their process id.
let s:jobs = {}

" The job's output and end reach lese#internal#invoke({id}, {kind}, {value}).
function! lese#internal#job_start(cmd, options, id) abort
  let l:id = a:id
  let l:options = extend(copy(a:options), {
        \ 'out_cb': { _, msg -> lese#internal#invoke(l:id, 'stdout', msg) },
        \ 'err_cb': { _, msg -> lese#internal#invoke(l:id, 'stderr', msg) },
        \ 'exit_cb': { _, code -> lese#internal#invoke(l:id, 'exit', code) },
        \ 'close_cb': { _ -> lese#internal#invoke(l:id, 'close', v:null) },
        \ })
  let l:job = job_start(a:cmd, l:options)
  if job_status(l:job) ==# 'fail'
    return 0
  endif
  let l:pid = job_info(l:job).process
  let s:jobs[l:pid] = l:job
  return l:pid
endfunction

function! lese#internal#job_stop(pid) abort
  if has_key(s:jobs, a:pid)
    call job_stop(s:jobs[a:pid], 'kill')
  endif
endfunction

function! lese#internal#job_forget(pid) abort
  if has_key(s:jobs, a:pid)
    call remove(s:jobs, a:pid)
  endif
endfunction

" Call lese#internal#invoke({id}) after {ms} milliseconds.
function! lese#internal#defer(ms, id) abort
  let l:id = a:id
  return timer_start(a:ms, { _ -> lese#internal#invoke(l:id) })
endfunction
