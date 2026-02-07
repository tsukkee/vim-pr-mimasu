let s:state = {
      \ 'base_bufnr': -1,
      \ 'base_winid': -1,
      \ 'current_winid': -1,
      \ }

function! mimasu#diff#open(base_ref, filepath, git_root) abort
  call mimasu#diff#close()

  let l:tree_winid = win_getid()
  let l:fullpath = a:git_root . '/' . a:filepath

  " Move to the right of tree window
  wincmd l

  " If we're still in the tree window (no window to the right), create a new split
  if win_getid() == l:tree_winid
    vnew
  endif

  " Open current file (real file for LSP support)
  if filereadable(l:fullpath)
    execute 'edit ' . fnameescape(l:fullpath)
  else
    enew
    setlocal buftype=nofile bufhidden=wipe
    call setline(1, ['(file deleted)'])
    setlocal nomodifiable
    let l:ext = fnamemodify(a:filepath, ':e')
    if !empty(l:ext)
      let &l:filetype = s:ext_to_filetype(l:ext)
    endif
  endif
  diffthis
  let s:state.current_winid = win_getid()

  " Create base file buffer to the left
  aboveleft vnew
  setlocal buftype=nofile bufhidden=wipe nobuflisted
  execute 'file ' . fnameescape('[base] ' . a:filepath)
  let l:content = mimasu#gh#get_base_file_content(a:base_ref, a:filepath)
  if l:content is v:null
    call setline(1, ['(new file)'])
  else
    call setline(1, l:content)
  endif
  setlocal nomodifiable
  let l:ext = fnamemodify(a:filepath, ':e')
  if !empty(l:ext)
    let &l:filetype = s:ext_to_filetype(l:ext)
  endif
  diffthis
  let s:state.base_bufnr = bufnr('%')
  let s:state.base_winid = win_getid()

  " Return cursor to tree window
  call win_gotoid(l:tree_winid)
endfunction

function! mimasu#diff#close() abort
  " Close base buffer window
  if s:state.base_winid != -1 && win_id2win(s:state.base_winid) > 0
    let l:winnr = win_id2win(s:state.base_winid)
    execute l:winnr . 'wincmd w'
    close
  endif

  " Turn off diff in current file window
  if s:state.current_winid != -1 && win_id2win(s:state.current_winid) > 0
    let l:winnr = win_id2win(s:state.current_winid)
    execute l:winnr . 'wincmd w'
    diffoff
  endif

  let s:state.base_bufnr = -1
  let s:state.base_winid = -1
  let s:state.current_winid = -1
endfunction

function! s:ext_to_filetype(ext) abort
  let l:map = {
        \ 'js': 'javascript',
        \ 'ts': 'typescript',
        \ 'tsx': 'typescriptreact',
        \ 'jsx': 'javascriptreact',
        \ 'py': 'python',
        \ 'rb': 'ruby',
        \ 'rs': 'rust',
        \ 'yml': 'yaml',
        \ 'md': 'markdown',
        \ 'sh': 'bash',
        \ 'zsh': 'zsh',
        \ 'ex': 'elixir',
        \ 'exs': 'elixir',
        \ }
  return get(l:map, a:ext, a:ext)
endfunction
