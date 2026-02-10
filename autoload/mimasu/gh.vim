let s:git_root_cache = ''
let s:base_file_cache = {}
let s:use_origin_prefix = -1

function! s:get_git_root() abort
  if !empty(s:git_root_cache)
    return s:git_root_cache
  endif
  let l:root = systemlist('git rev-parse --show-toplevel')[0]
  if v:shell_error
    return ''
  endif
  let s:git_root_cache = l:root
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
  let l:cmd = ['gh', 'pr', 'view', '--json', 'baseRefName,headRefName,headRefOid,number,title,url,files']
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

function! mimasu#gh#get_base_file_content(base_ref, filepath, git_root) abort
  let l:cache_key = a:base_ref . ':' . a:filepath
  if has_key(s:base_file_cache, l:cache_key)
    return s:base_file_cache[l:cache_key]
  endif

  let l:ref = s:resolve_base_ref(a:base_ref, a:git_root)
  let l:result = systemlist('git -C ' . shellescape(a:git_root) . ' show ' . shellescape(l:ref . ':' . a:filepath))
  if v:shell_error
    let s:base_file_cache[l:cache_key] = v:null
    return v:null
  endif
  let s:base_file_cache[l:cache_key] = l:result
  return l:result
endfunction

function! s:resolve_base_ref(base_ref, git_root) abort
  if s:use_origin_prefix == 1
    return 'origin/' . a:base_ref
  elseif s:use_origin_prefix == 0
    return a:base_ref
  endif

  " First call: determine whether origin/ prefix works
  let l:check = systemlist('git -C ' . shellescape(a:git_root) . ' rev-parse --verify origin/' . shellescape(a:base_ref))
  if !v:shell_error
    let s:use_origin_prefix = 1
    return 'origin/' . a:base_ref
  endif
  let s:use_origin_prefix = 0
  return a:base_ref
endfunction

function! mimasu#gh#clear_cache() abort
  let s:git_root_cache = ''
  let s:base_file_cache = {}
  let s:use_origin_prefix = -1
endfunction

function! mimasu#gh#get_git_root() abort
  return s:get_git_root()
endfunction

function! mimasu#gh#submit_review_comment(pr_info, filepath, line, end_line, side, body, Callback) abort
  let l:root = s:get_git_root()
  let l:ctx = {
        \ 'pr_info': a:pr_info,
        \ 'filepath': a:filepath,
        \ 'line': a:line,
        \ 'end_line': a:end_line,
        \ 'side': a:side,
        \ 'body': a:body,
        \ 'Callback': a:Callback,
        \ 'root': l:root,
        \ }

  " Check for existing PENDING review
  let l:endpoint = 'repos/{owner}/{repo}/pulls/' . a:pr_info.number . '/reviews'
  let l:cmd = ['gh', 'api', l:endpoint, '--jq',
        \ '[.[] | select(.state == "PENDING")][0] | .node_id']
  let l:out_buf = []
  let l:err_buf = []
  let l:ctx.out_buf = l:out_buf
  let l:ctx.err_buf = l:err_buf

  call job_start(l:cmd, {
        \ 'cwd': l:root,
        \ 'out_cb': {_ch, msg -> add(l:out_buf, msg)},
        \ 'err_cb': {_ch, msg -> add(l:err_buf, msg)},
        \ 'exit_cb': function('s:on_find_pending_review', [l:ctx]),
        \ })
endfunction

function! s:on_find_pending_review(ctx, _job, exit_code) abort
  let l:node_id = ''
  if a:exit_code == 0
    let l:out = trim(join(a:ctx.out_buf, ''))
    if !empty(l:out) && l:out !=# 'null'
      let l:node_id = l:out
    endif
  endif

  if !empty(l:node_id)
    call s:add_comment_to_review(a:ctx, l:node_id)
  else
    call s:create_review_with_comment(a:ctx)
  endif
endfunction

function! s:create_review_with_comment(ctx) abort
  let l:comment = {'path': a:ctx.filepath, 'body': a:ctx.body, 'side': a:ctx.side}
  if a:ctx.end_line > 0 && a:ctx.end_line != a:ctx.line
    let l:comment.start_line = a:ctx.line
    let l:comment.line = a:ctx.end_line
  else
    let l:comment.line = a:ctx.line
  endif

  let l:review = {'commit_id': a:ctx.pr_info.headRefOid, 'comments': [l:comment]}
  let l:json = json_encode(l:review)
  let l:endpoint = 'repos/{owner}/{repo}/pulls/' . a:ctx.pr_info.number . '/reviews'
  call s:run_api_post(a:ctx.root, l:endpoint, l:json, a:ctx.Callback)
endfunction

function! s:add_comment_to_review(ctx, review_node_id) abort
  let l:vars = {
        \ 'pullRequestReviewId': a:review_node_id,
        \ 'body': a:ctx.body,
        \ 'path': a:ctx.filepath,
        \ 'line': a:ctx.line,
        \ 'side': a:ctx.side,
        \ }
  if a:ctx.end_line > 0 && a:ctx.end_line != a:ctx.line
    let l:vars.startLine = a:ctx.line
    let l:vars.startSide = a:ctx.side
    let l:vars.line = a:ctx.end_line
  endif

  let l:query = 'mutation AddComment($pullRequestReviewId: ID!, $body: String!, $path: String!, $line: Int!, $side: DiffSide, $startLine: Int, $startSide: DiffSide) {'
        \ . ' addPullRequestReviewThread(input: {'
        \ . '   pullRequestReviewId: $pullRequestReviewId,'
        \ . '   body: $body, path: $path, line: $line, side: $side,'
        \ . '   startLine: $startLine, startSide: $startSide'
        \ . ' }) { thread { id } }'
        \ . '}'
  let l:json = json_encode({'query': l:query, 'variables': l:vars})
  let l:cmd = ['gh', 'api', 'graphql', '--input', '-']

  let l:out_buf = []
  let l:err_buf = []
  let l:cb_ctx = {'out_buf': l:out_buf, 'err_buf': l:err_buf, 'Callback': a:ctx.Callback}

  let l:job = job_start(l:cmd, {
        \ 'cwd': a:ctx.root,
        \ 'in_mode': 'raw',
        \ 'out_cb': {_ch, msg -> add(l:out_buf, msg)},
        \ 'err_cb': {_ch, msg -> add(l:err_buf, msg)},
        \ 'exit_cb': function('s:on_submit_exit', [l:cb_ctx]),
        \ })
  let l:ch = job_getchannel(l:job)
  call ch_sendraw(l:ch, l:json)
  call ch_close_in(l:ch)
endfunction

function! s:run_api_post(root, endpoint, json, Callback) abort
  let l:cmd = ['gh', 'api', a:endpoint, '--method', 'POST', '--input', '-']
  let l:out_buf = []
  let l:err_buf = []
  let l:ctx = {'out_buf': l:out_buf, 'err_buf': l:err_buf, 'Callback': a:Callback}

  let l:job = job_start(l:cmd, {
        \ 'cwd': a:root,
        \ 'in_mode': 'raw',
        \ 'out_cb': {_ch, msg -> add(l:out_buf, msg)},
        \ 'err_cb': {_ch, msg -> add(l:err_buf, msg)},
        \ 'exit_cb': function('s:on_submit_exit', [l:ctx]),
        \ })
  let l:ch = job_getchannel(l:job)
  call ch_sendraw(l:ch, a:json)
  call ch_close_in(l:ch)
endfunction

function! s:on_submit_exit(ctx, _job, exit_code) abort
  let l:Callback = a:ctx.Callback
  if a:exit_code != 0
    let l:err = join(a:ctx.err_buf, "\n")
    let l:out = join(a:ctx.out_buf, "\n")
    if !empty(l:out)
      let l:err .= "\n" . l:out
    endif
    call timer_start(0, {-> l:Callback(v:null, l:err)})
    return
  endif
  try
    let l:json_str = join(a:ctx.out_buf, "\n")
    let l:result = json_decode(l:json_str)
    call timer_start(0, {-> l:Callback(l:result, '')})
  catch
    call timer_start(0, {-> l:Callback(v:null, 'Failed to parse response')})
  endtry
endfunction
