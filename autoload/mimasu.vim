let s:state = {
      \ 'mode': 'pr',
      \ 'base_rev': 'HEAD',
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

  let s:state.mode = 'pr'
  call s:open_tree_window()

  " Show loading message
  setlocal modifiable
  call setline(1, ['Loading PR info...'])
  setlocal nomodifiable

  call mimasu#gh#fetch_pr_info(function('s:on_pr_info_received'))
endfunction

" Open the local "git diff" review mode comparing the working tree against
" base_rev (defaults to HEAD: staged + unstaged changes).
function! mimasu#open_diff(...) abort
  let l:base_rev = a:0 > 0 && !empty(a:1) ? a:1 : 'HEAD'

  " Toggle: if tree is already open, close it
  if s:state.tree_winid != -1 && win_id2win(s:state.tree_winid) > 0
    call mimasu#close()
    return
  endif

  if !mimasu#gh#check_prerequisites()
    return
  endif

  let s:state.mode = 'diff'
  let s:state.base_rev = l:base_rev
  call s:open_tree_window()

  setlocal modifiable
  call setline(1, ['Loading git diff (' . l:base_rev . ')...'])
  setlocal nomodifiable

  call s:load_diff_info()
endfunction

function! s:load_diff_info() abort
  let l:git_root = mimasu#gh#get_git_root()
  let l:info = mimasu#git#build_info(s:state.base_rev, l:git_root)
  call s:on_pr_info_received(l:info)
endfunction

" Command-line completion for :MimasuDiff (branches, tags and HEAD).
function! mimasu#complete_rev(arglead, cmdline, cursorpos) abort
  let l:git_root = mimasu#gh#get_git_root()
  if empty(l:git_root)
    return []
  endif
  let l:refs = systemlist('git -C ' . shellescape(l:git_root)
        \ . ' for-each-ref --format="%(refname:short)" refs/heads refs/tags refs/remotes')
  if v:shell_error
    let l:refs = []
  endif
  let l:candidates = ['HEAD'] + l:refs
  return filter(l:candidates, 'stridx(v:val, a:arglead) == 0')
endfunction

function! s:on_pr_info_received(pr_info) abort
  " Check if tree window is still open
  if s:state.tree_winid == -1 || win_id2win(s:state.tree_winid) == 0
    return
  endif

  if a:pr_info is v:null
    call win_gotoid(s:state.tree_winid)
    setlocal modifiable
    if s:state.mode ==# 'diff'
      call s:set_buffer_lines(['Failed to read git diff.', '', 'Make sure:', '  - You are in a git repository', '  - The base rev "' . s:state.base_rev . '" exists'])
    else
      call s:set_buffer_lines(['No PR found for current branch.', '', 'Make sure:', '  - You are on a branch with an open PR', '  - gh CLI is authenticated (gh auth status)'])
    endif
    setlocal nomodifiable
    return
  endif

  if empty(get(a:pr_info, 'files', []))
    call win_gotoid(s:state.tree_winid)
    setlocal modifiable
    if s:state.mode ==# 'diff'
      call s:set_buffer_lines(['No changes against ' . s:state.base_rev . '.'])
    else
      call s:set_buffer_lines(['This PR has no changed files.'])
    endif
    setlocal nomodifiable
    let s:state.pr_info = a:pr_info
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
  call mimasu#diff#open(s:state.pr_info, l:path, l:git_root)
endfunction

function! mimasu#start_comment() abort range
  if empty(s:state.pr_info) || empty(s:state.current_file)
    echohl WarningMsg
    echomsg 'mimasu: No file selected'
    echohl None
    return
  endif

  let l:winid = win_getid()
  let l:side = 'RIGHT'
  " Check if cursor is in the base (left) diff window
  if has_key(mimasu#diff#get_state(), 'base_winid') && l:winid == mimasu#diff#get_state().base_winid
    let l:side = 'LEFT'
  endif

  let l:line = a:firstline
  let l:end_line = a:lastline
  call mimasu#review#start_comment(s:state.pr_info, s:state.current_file, l:line, l:end_line, l:side)
endfunction

function! mimasu#open_in_browser() abort
  call mimasu#review#open_in_browser()
endfunction

function! mimasu#close() abort
  call mimasu#diff#close(s:state.tree_winid)

  " Keep 'hidden' on while tearing down the tree so an unsaved edit kept open
  " in the diff pane never aborts the close.
  let l:save_hidden = &hidden
  set hidden
  try
    if s:state.tree_winid != -1 && win_id2win(s:state.tree_winid) > 0
      " If the tree is the only window left in the tab, replace its content
      " with an empty buffer instead of closing it (closing the last window
      " raises E444).
      if winnr('$') <= 1
        call win_execute(s:state.tree_winid, 'enew')
      else
        call win_execute(s:state.tree_winid, 'close')
      endif
    endif

    " The tree is a throwaway scratch buffer; it carries a 'modified' flag from
    " setline() even though it is nomodifiable, so force-wipe it.
    if s:state.tree_bufnr != -1 && bufexists(s:state.tree_bufnr)
      execute 'bwipeout! ' . s:state.tree_bufnr
    endif
  finally
    let &hidden = l:save_hidden
  endtry

  let s:state.tree_bufnr = -1
  let s:state.tree_winid = -1
  let s:state.pr_info = {}
  let s:state.tree_data = {}
  let s:state.current_file = ''
  let s:state.mode = 'pr'
  let s:state.base_rev = 'HEAD'
endfunction

function! mimasu#render_tree() abort
  call s:render_tree()
endfunction

function! mimasu#refresh() abort
  if s:state.tree_winid == -1 || win_id2win(s:state.tree_winid) == 0
    echohl WarningMsg
    echomsg 'mimasu: Tree window is not open'
    echohl None
    return
  endif

  call win_gotoid(s:state.tree_winid)
  setlocal modifiable

  if s:state.mode ==# 'diff'
    call mimasu#git#clear_cache()
    call s:set_buffer_lines(['Refreshing git diff (' . s:state.base_rev . ')...'])
    setlocal nomodifiable
    call s:load_diff_info()
    return
  endif

  call mimasu#gh#clear_cache()
  call s:set_buffer_lines(['Refreshing PR info...'])
  setlocal nomodifiable

  call mimasu#gh#fetch_pr_info(function('s:on_pr_info_received'))
endfunction
