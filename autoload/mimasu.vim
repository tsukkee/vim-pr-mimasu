let s:state = {
      \ 'tree_bufnr': -1,
      \ 'tree_winid': -1,
      \ 'pr_info': {},
      \ 'tree_data': {},
      \ 'current_file': '',
      \ }

function! mimasu#open() abort
  " Toggle: if tree is already open, close it
  if s:state.tree_winid != -1 && win_id2win(s:state.tree_winid) > 0
    call mimasu#close()
    return
  endif

  if !mimasu#gh#check_prerequisites()
    return
  endif

  call s:open_tree_window()

  " Show loading message
  setlocal modifiable
  call setline(1, ['Loading PR info...'])
  setlocal nomodifiable

  call mimasu#gh#fetch_pr_info(function('s:on_pr_info_received'))
endfunction

function! s:on_pr_info_received(pr_info) abort
  " Check if tree window is still open
  if s:state.tree_winid == -1 || win_id2win(s:state.tree_winid) == 0
    return
  endif

  if a:pr_info is v:null
    call win_gotoid(s:state.tree_winid)
    setlocal modifiable
    call s:set_buffer_lines(['No PR found for current branch.', '', 'Make sure:', '  - You are on a branch with an open PR', '  - gh CLI is authenticated (gh auth status)'])
    setlocal nomodifiable
    return
  endif

  let s:state.pr_info = a:pr_info
  let s:state.tree_data = mimasu#tree#build(get(a:pr_info, 'files', []))
  call s:render_tree()
endfunction

function! s:open_tree_window() abort
  let l:cur_winid = win_getid()

  " Reuse existing buffer if possible
  if s:state.tree_bufnr != -1 && bufexists(s:state.tree_bufnr)
    execute g:mimasu_sidebar_position . ' sbuffer ' . s:state.tree_bufnr
  else
    execute g:mimasu_sidebar_position . ' new'
    let s:state.tree_bufnr = bufnr('%')
  endif

  execute 'vertical resize ' . g:mimasu_sidebar_width
  setlocal filetype=mimasu_tree
  let s:state.tree_winid = win_getid()
endfunction

function! s:render_tree() abort
  if s:state.tree_winid == -1 || win_id2win(s:state.tree_winid) == 0
    return
  endif

  let l:cur_winid = win_getid()
  call win_gotoid(s:state.tree_winid)

  let l:save_cursor = getpos('.')
  let l:lines = mimasu#tree#render(s:state.tree_data, s:state.pr_info)
  call s:set_buffer_lines(l:lines)
  call setpos('.', l:save_cursor)

  call win_gotoid(l:cur_winid)
endfunction

function! s:set_buffer_lines(lines) abort
  setlocal modifiable
  silent! %delete _
  call setline(1, a:lines)
  setlocal nomodifiable
endfunction

function! mimasu#toggle_or_select() abort
  let l:lnum = line('.')

  if mimasu#tree#is_dir_at_line(l:lnum)
    call mimasu#tree#toggle_dir(l:lnum)
    call s:render_tree()
    return
  endif

  let l:path = mimasu#tree#get_path_at_line(l:lnum)
  if empty(l:path)
    return
  endif

  let s:state.current_file = l:path
  let l:git_root = mimasu#gh#get_git_root()
  call mimasu#diff#open(s:state.pr_info.baseRefName, l:path, l:git_root)
endfunction

function! mimasu#close() abort
  call mimasu#diff#close(s:state.tree_winid)

  if s:state.tree_winid != -1 && win_id2win(s:state.tree_winid) > 0
    let l:winnr = win_id2win(s:state.tree_winid)
    execute l:winnr . 'wincmd w'
    close
  endif

  if s:state.tree_bufnr != -1 && bufexists(s:state.tree_bufnr)
    execute 'bwipeout ' . s:state.tree_bufnr
  endif

  let s:state.tree_bufnr = -1
  let s:state.tree_winid = -1
  let s:state.pr_info = {}
  let s:state.tree_data = {}
  let s:state.current_file = ''
endfunction

function! mimasu#refresh() abort
  if s:state.tree_winid == -1 || win_id2win(s:state.tree_winid) == 0
    echohl WarningMsg
    echomsg 'mimasu: Tree window is not open'
    echohl None
    return
  endif

  call mimasu#gh#clear_cache()

  call win_gotoid(s:state.tree_winid)
  setlocal modifiable
  call s:set_buffer_lines(['Refreshing PR info...'])
  setlocal nomodifiable

  call mimasu#gh#fetch_pr_info(function('s:on_pr_info_received'))
endfunction
