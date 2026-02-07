function! s:get_git_root() abort
  let l:root = systemlist('git rev-parse --show-toplevel')[0]
  if v:shell_error
    return ''
  endif
  return l:root
endfunction

function! mimasu#gh#check_prerequisites() abort
  if !executable('gh')
    echohl ErrorMsg
    echomsg 'mimasu: gh CLI is not installed'
    echohl None
    return 0
  endif
  let l:root = s:get_git_root()
  if empty(l:root)
    echohl ErrorMsg
    echomsg 'mimasu: Not in a git repository'
    echohl None
    return 0
  endif
  return 1
endfunction

function! mimasu#gh#fetch_pr_info(Callback) abort
  let l:root = s:get_git_root()
  let l:cmd = ['gh', 'pr', 'view', '--json', 'baseRefName,headRefName,number,title,url,files']
  let l:out_buf = []
  let l:err_buf = []
  let l:ctx = {'out_buf': l:out_buf, 'err_buf': l:err_buf, 'Callback': a:Callback}

  call job_start(l:cmd, {
        \ 'cwd': l:root,
        \ 'out_cb': {_ch, msg -> add(l:out_buf, msg)},
        \ 'err_cb': {_ch, msg -> add(l:err_buf, msg)},
        \ 'exit_cb': function('s:on_fetch_exit', [l:ctx]),
        \ })
endfunction

function! s:on_fetch_exit(ctx, _job, exit_code) abort
  let l:Callback = a:ctx.Callback
  if a:exit_code != 0
    call timer_start(0, {-> l:Callback(v:null)})
    return
  endif
  try
    let l:json_str = join(a:ctx.out_buf, "\n")
    let l:pr_info = json_decode(l:json_str)
    call timer_start(0, {-> l:Callback(l:pr_info)})
  catch
    call timer_start(0, {-> l:Callback(v:null)})
  endtry
endfunction

function! mimasu#gh#get_base_file_content(base_ref, filepath) abort
  let l:root = s:get_git_root()
  let l:result = systemlist('git -C ' . shellescape(l:root) . ' show ' . shellescape('origin/' . a:base_ref . ':' . a:filepath))
  if v:shell_error
    let l:result = systemlist('git -C ' . shellescape(l:root) . ' show ' . shellescape(a:base_ref . ':' . a:filepath))
    if v:shell_error
      return v:null
    endif
  endif
  return l:result
endfunction

function! mimasu#gh#get_git_root() abort
  return s:get_git_root()
endfunction
