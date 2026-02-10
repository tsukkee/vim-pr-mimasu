let s:line_map = []

function! mimasu#tree#build(files) abort
  let l:tree = {'_children': {}, '_open': 1}
  for l:file in a:files
    let l:path = l:file.path
    let l:parts = split(l:path, '/')
    let l:node = l:tree
    for l:i in range(len(l:parts))
      let l:part = l:parts[l:i]
      if l:i < len(l:parts) - 1
        if !has_key(l:node._children, l:part)
          let l:node._children[l:part] = {'_children': {}, '_open': 1}
        endif
        let l:node = l:node._children[l:part]
      else
        let l:node._children[l:part] = {
              \ '_path': l:path,
              \ '_additions': get(l:file, 'additions', 0),
              \ '_deletions': get(l:file, 'deletions', 0),
              \ }
      endif
    endfor
  endfor
  return l:tree
endfunction

function! mimasu#tree#render(tree, pr_info) abort
  let s:line_map = []
  let l:lines = []

  call add(l:lines, '#' . a:pr_info.number . ' ' . a:pr_info.title)
  call add(s:line_map, {'type': 'header'})

  call add(l:lines, a:pr_info.url)
  call add(s:line_map, {'type': 'header'})

  call add(l:lines, repeat('─', 40))
  call add(s:line_map, {'type': 'separator'})

  call s:render_node(a:tree, l:lines, 0)
  return l:lines
endfunction

function! s:render_node(node, lines, depth) abort
  let l:dirs = []
  let l:files = []
  for [l:name, l:child] in items(a:node._children)
    if has_key(l:child, '_children')
      call add(l:dirs, [l:name, l:child])
    else
      call add(l:files, [l:name, l:child])
    endif
  endfor

  call sort(l:dirs, {a, b -> a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0})
  call sort(l:files, {a, b -> a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0})

  let l:indent = repeat('  ', a:depth)
  for [l:name, l:child] in l:dirs
    let l:icon = l:child._open ? g:mimasu_fold_icons[0] : g:mimasu_fold_icons[1]
    call add(a:lines, l:indent . l:icon . ' ' . l:name . '/')
    call add(s:line_map, {'type': 'dir', 'node': l:child, 'name': l:name})
    if l:child._open
      call s:render_node(l:child, a:lines, a:depth + 1)
    endif
  endfor

  for [l:name, l:child] in l:files
    let l:changes = ''
    if l:child._additions > 0 || l:child._deletions > 0
      let l:parts = []
      if l:child._additions > 0
        call add(l:parts, '+' . l:child._additions)
      endif
      if l:child._deletions > 0
        call add(l:parts, '-' . l:child._deletions)
      endif
      let l:changes = ' [' . join(l:parts, ' ') . ']'
    endif
    let l:comment_count = mimasu#review#get_comment_count(l:child._path)
    let l:comment_mark = l:comment_count > 0 ? ' {' . l:comment_count . '}' : ''
    call add(a:lines, l:indent . '  ' . l:name . l:changes . l:comment_mark)
    call add(s:line_map, {'type': 'file', 'path': l:child._path})
  endfor
endfunction

function! mimasu#tree#get_path_at_line(lnum) abort
  let l:idx = a:lnum - 1
  if l:idx < 0 || l:idx >= len(s:line_map)
    return ''
  endif
  let l:entry = s:line_map[l:idx]
  if l:entry.type ==# 'file'
    return l:entry.path
  endif
  return ''
endfunction

function! mimasu#tree#toggle_dir(lnum) abort
  let l:idx = a:lnum - 1
  if l:idx < 0 || l:idx >= len(s:line_map)
    return
  endif
  let l:entry = s:line_map[l:idx]
  if l:entry.type ==# 'dir'
    let l:entry.node._open = !l:entry.node._open
  endif
endfunction

function! mimasu#tree#is_dir_at_line(lnum) abort
  let l:idx = a:lnum - 1
  if l:idx < 0 || l:idx >= len(s:line_map)
    return 0
  endif
  return s:line_map[l:idx].type ==# 'dir'
endfunction
