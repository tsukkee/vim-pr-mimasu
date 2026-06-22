let s:state = {
      \ 'base_bufnr': -1,
      \ 'base_winid': -1,
      \ 'current_winid': -1,
      \ }

function! mimasu#diff#open(base_ref, head_ref_oid, filepath, git_root) abort
  let l:tree_winid = win_getid()
  call mimasu#diff#close(l:tree_winid)
  let l:fullpath = a:git_root . '/' . a:filepath

  " Move to the right of tree window
  wincmd l

  " If we're still in the tree window (no window to the right), create a new split
  if win_getid() == l:tree_winid
    rightbelow vnew
  endif

  " Open current file (real file for LSP support)
  if filereadable(l:fullpath)
    execute 'edit ' . fnameescape(l:fullpath)
  else
    enew
    setlocal buftype=nofile bufhidden=wipe
    execute 'file ' . fnameescape('[deleted] ' . a:filepath)
    filetype detect
    call setline(1, ['(file deleted)'])
    setlocal nomodifiable
  endif
  diffthis
  let s:state.current_winid = win_getid()

  " Create base file buffer to the left
  aboveleft vnew
  setlocal buftype=nofile bufhidden=wipe nobuflisted
  execute 'silent file ' . fnameescape('[base] ' . a:filepath)
  filetype detect
  let l:content = mimasu#gh#get_base_file_content(a:base_ref, a:head_ref_oid, a:filepath, a:git_root)
  if l:content is v:null
    call setline(1, ['(new file)'])
  else
    call setline(1, l:content)
  endif
  setlocal nomodifiable wrap
  diffthis
  let s:state.base_bufnr = bufnr('%')
  let s:state.base_winid = win_getid()

  " Set review keymaps on both diff windows
  call s:set_review_keymaps(s:state.current_winid)
  call s:set_review_keymaps(s:state.base_winid)

  " Restore tree width, then equalize diff windows
  call win_gotoid(l:tree_winid)
  execute 'vertical resize ' . g:mimasu_sidebar_width
  wincmd =
endfunction

function! s:set_review_keymaps(winid) abort
  let l:cur = win_getid()
  call win_gotoid(a:winid)
  setlocal wrap
  nnoremap <buffer> <silent> <Leader>c <Cmd>call mimasu#start_comment()<CR>
  xnoremap <buffer> <silent> <Leader>c :call mimasu#start_comment()<CR>
  nnoremap <buffer> <silent> <Leader>x <Cmd>call mimasu#open_in_browser()<CR>
  nnoremap <buffer> <silent> <Leader>w <Cmd>call mimasu#diff#toggle_wrap()<CR>
  nnoremap <buffer> <silent> <Leader>i <Cmd>call mimasu#diff#toggle_iwhiteall()<CR>
  call win_gotoid(l:cur)
endfunction

function! mimasu#diff#toggle_wrap() abort
  let l:state = mimasu#diff#get_state()
  for l:winid in [l:state.base_winid, l:state.current_winid]
    if l:winid != -1 && win_id2win(l:winid) > 0
      call win_execute(l:winid, 'setlocal wrap!')
    endif
  endfor
endfunction

function! mimasu#diff#toggle_iwhiteall() abort
  if stridx(&diffopt, 'iwhiteall') >= 0
    set diffopt-=iwhiteall
  else
    set diffopt+=iwhiteall
  endif
  diffupdate
endfunction

function! mimasu#diff#get_state() abort
  return s:state
endfunction

function! mimasu#diff#close(tree_winid) abort
  " Close all windows in current tab except the tree window
  for l:winid in gettabinfo(tabpagenr())[0].windows
    if l:winid != a:tree_winid && win_id2win(l:winid) > 0
      let l:winnr = win_id2win(l:winid)
      execute l:winnr . 'close'
    endif
  endfor

  let s:state.base_bufnr = -1
  let s:state.base_winid = -1
  let s:state.current_winid = -1
endfunction
