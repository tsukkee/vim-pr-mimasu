let s:state = {
      \ 'comment_bufnr': -1,
      \ 'comment_winid': -1,
      \ 'filepath': '',
      \ 'line': 0,
      \ 'end_line': 0,
      \ 'side': '',
      \ 'pending_comments': [],
      \ }

function! mimasu#review#start_comment(pr_info, filepath, line, end_line, side) abort
  " Close existing comment buffer if open
  call s:close_comment_buffer()

  let s:state.filepath = a:filepath
  let s:state.line = a:line
  let s:state.end_line = a:end_line
  let s:state.side = a:side
  let s:state.pr_info = a:pr_info

  " Open a small split at the bottom
  botright new
  resize 8

  let s:state.comment_bufnr = bufnr('%')
  let s:state.comment_winid = win_getid()

  " Build header for the status line
  let l:range = a:line
  if a:end_line > 0 && a:end_line != a:line
    let l:range = a:line . '-' . a:end_line
  endif
  let l:side_label = a:side ==# 'LEFT' ? 'base' : 'current'
  let &l:statusline = ' Comment: ' . a:filepath . ':' . l:range . ' (' . l:side_label . ')  |  :w Submit  q Cancel'

  setlocal filetype=mimasu_comment
endfunction

function! mimasu#review#submit() abort
  if s:state.comment_bufnr == -1
    return
  endif

  let l:lines = getbufline(s:state.comment_bufnr, 1, '$')
  let l:body = join(l:lines, "\n")
  let l:body = substitute(l:body, '^\n\+\|\n\+$', '', 'g')

  if empty(l:body)
    echohl WarningMsg
    echomsg 'mimasu: Comment is empty'
    echohl None
    return
  endif

  echomsg 'mimasu: Submitting comment...'

  call mimasu#gh#submit_review_comment(
        \ s:state.pr_info,
        \ s:state.filepath,
        \ s:state.line,
        \ s:state.end_line,
        \ s:state.side,
        \ l:body,
        \ function('s:on_comment_submitted'),
        \ )
endfunction

function! s:on_comment_submitted(result, err) abort
  if a:result is v:null
    echohl ErrorMsg
    echomsg 'mimasu: Failed to submit comment: ' . a:err
    echohl None
    return
  endif

  call add(s:state.pending_comments, {
        \ 'filepath': s:state.filepath,
        \ 'line': s:state.line,
        \ 'end_line': s:state.end_line,
        \ 'side': s:state.side,
        \ })

  echomsg 'mimasu: Comment submitted (pending review)'
  call s:close_comment_buffer()
  call mimasu#render_tree()
endfunction

function! mimasu#review#cancel() abort
  call s:close_comment_buffer()
endfunction

function! s:close_comment_buffer() abort
  if s:state.comment_bufnr != -1 && bufexists(s:state.comment_bufnr)
    let l:winid = s:state.comment_winid
    if l:winid != -1 && win_id2win(l:winid) > 0
      let l:winnr = win_id2win(l:winid)
      execute l:winnr . 'close'
    endif
    if bufexists(s:state.comment_bufnr)
      execute 'bwipeout! ' . s:state.comment_bufnr
    endif
  endif
  let s:state.comment_bufnr = -1
  let s:state.comment_winid = -1
endfunction

function! mimasu#review#open_in_browser() abort
  call system('gh pr view --web')
endfunction

function! mimasu#review#get_comment_count(filepath) abort
  let l:count = 0
  for l:c in s:state.pending_comments
    if l:c.filepath ==# a:filepath
      let l:count += 1
    endif
  endfor
  return l:count
endfunction

function! mimasu#review#clear() abort
  let s:state.pending_comments = []
endfunction
