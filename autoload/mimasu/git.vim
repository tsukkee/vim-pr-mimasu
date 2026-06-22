" Data source for the local "git diff" review mode.
" Mirrors the shape of the pr_info dict produced by mimasu#gh# so that
" tree.vim / diff.vim can be reused without changes.

let s:base_file_cache = {}

" Build a pr_info-like dict for `git diff <base_rev>`.
" base_rev defaults to 'HEAD' (staged + unstaged working tree changes).
function! mimasu#git#build_info(base_rev, git_root) abort
  let l:files = s:collect_files(a:base_rev, a:git_root)
  if l:files is v:null
    return v:null
  endif

  return {
        \ 'mode': 'diff',
        \ 'base_rev': a:base_rev,
        \ 'title': 'git diff ' . a:base_rev,
        \ 'url': a:git_root,
        \ 'baseRefName': a:base_rev,
        \ 'files': l:files,
        \ }
endfunction

function! s:collect_files(base_rev, git_root) abort
  let l:status = s:run_diff(a:git_root, ['--name-status', '-z', a:base_rev])
  if l:status is v:null
    return v:null
  endif

  let l:numstat = s:run_diff(a:git_root, ['--numstat', '-z', a:base_rev])
  let l:changes = l:numstat is v:null ? {} : s:parse_numstat(l:numstat)

  let l:files = []
  for l:entry in s:parse_name_status(l:status)
    let l:change = get(l:changes, l:entry.path, {'additions': 0, 'deletions': 0})
    let l:file = {
          \ 'path': l:entry.path,
          \ 'status': l:entry.status,
          \ 'additions': l:change.additions,
          \ 'deletions': l:change.deletions,
          \ }
    " For renames/copies the base content lives at the old path.
    if !empty(get(l:entry, 'old_path', ''))
      let l:file.base_path = l:entry.old_path
    endif
    call add(l:files, l:file)
  endfor
  return l:files
endfunction

" Run `git -C <root> diff <args...>` and return the raw NUL-joined output as a
" single string, or v:null on failure.
function! s:run_diff(git_root, args) abort
  let l:cmd = ['git', '-C', a:git_root, 'diff'] + a:args
  let l:out = systemlist(join(map(copy(l:cmd), 'shellescape(v:val)'), ' '))
  if v:shell_error
    return v:null
  endif
  " systemlist splits on newlines; the records are NUL separated, so re-join.
  return join(l:out, "\n")
endfunction

" Parse `git diff --name-status -z` output.
" Records: STATUS\0path\0  (or for renames/copies) R###\0old\0new\0
function! s:parse_name_status(raw) abort
  let l:fields = split(a:raw, "\n", 1)
  let l:result = []
  let l:i = 0
  while l:i < len(l:fields)
    let l:status = l:fields[l:i]
    if empty(l:status)
      let l:i += 1
      continue
    endif
    let l:code = l:status[0]
    let l:old_path = ''
    if l:code ==# 'R' || l:code ==# 'C'
      " R<score>\0<old>\0<new>\0 : the new path is what we want to show.
      let l:old_path = get(l:fields, l:i + 1, '')
      let l:path = get(l:fields, l:i + 2, '')
      let l:i += 3
    else
      let l:path = get(l:fields, l:i + 1, '')
      let l:i += 2
    endif
    if !empty(l:path)
      call add(l:result, {'status': l:code, 'path': l:path, 'old_path': l:old_path})
    endif
  endwhile
  return l:result
endfunction

" Parse `git diff --numstat -z` output into {path: {additions, deletions}}.
" Records: add\tdel\tpath\0  (or for renames) add\tdel\t\0old\0new\0
function! s:parse_numstat(raw) abort
  let l:fields = split(a:raw, "\n", 1)
  let l:result = {}
  let l:i = 0
  while l:i < len(l:fields)
    let l:field = l:fields[l:i]
    if empty(l:field)
      let l:i += 1
      continue
    endif
    let l:cols = split(l:field, "\t", 1)
    if len(l:cols) < 3
      let l:i += 1
      continue
    endif
    let l:add = l:cols[0]
    let l:del = l:cols[1]
    let l:path = l:cols[2]
    if empty(l:path)
      " Rename/copy: real paths are the next two NUL-separated fields.
      let l:path = get(l:fields, l:i + 2, '')
      let l:i += 3
    else
      let l:i += 1
    endif
    if empty(l:path)
      continue
    endif
    let l:result[l:path] = {
          \ 'additions': l:add ==# '-' ? 0 : str2nr(l:add),
          \ 'deletions': l:del ==# '-' ? 0 : str2nr(l:del),
          \ }
  endwhile
  return l:result
endfunction

" Return the base (pre-change) content of filepath at base_rev, or v:null if the
" file does not exist there (e.g. a newly added file).
function! mimasu#git#get_base_file_content(base_rev, filepath, git_root) abort
  let l:cache_key = a:base_rev . ':' . a:filepath
  if has_key(s:base_file_cache, l:cache_key)
    return s:base_file_cache[l:cache_key]
  endif

  let l:result = systemlist('git -C ' . shellescape(a:git_root) . ' show ' . shellescape(a:base_rev . ':' . a:filepath))
  if v:shell_error
    let s:base_file_cache[l:cache_key] = v:null
    return v:null
  endif
  let s:base_file_cache[l:cache_key] = l:result
  return l:result
endfunction

function! mimasu#git#clear_cache() abort
  let s:base_file_cache = {}
endfunction
