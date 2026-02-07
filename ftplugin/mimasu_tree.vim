if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal nonumber
setlocal norelativenumber
setlocal noswapfile
setlocal nobuflisted
setlocal buftype=nofile
setlocal bufhidden=hide
setlocal nomodifiable
setlocal winfixwidth
setlocal cursorline
setlocal nowrap
setlocal nospell
setlocal signcolumn=no
setlocal foldcolumn=0

setlocal statusline=\ PR\ Review

nnoremap <buffer> <silent> <CR> <Cmd>call mimasu#toggle_or_select()<CR>
nnoremap <buffer> <silent> o <Cmd>call mimasu#toggle_or_select()<CR>
nnoremap <buffer> <silent> <2-LeftMouse> <Cmd>call mimasu#toggle_or_select()<CR>
nnoremap <buffer> <silent> q <Cmd>call mimasu#close()<CR>
nnoremap <buffer> <silent> R <Cmd>call mimasu#refresh()<CR>

let b:undo_ftplugin = 'setlocal number< relativenumber< swapfile< buflisted< buftype< bufhidden< modifiable< winfixwidth< cursorline< wrap< spell< signcolumn< foldcolumn< statusline<'
      \ . '| nunmap <buffer> <CR>'
      \ . '| nunmap <buffer> o'
      \ . '| nunmap <buffer> <2-LeftMouse>'
      \ . '| nunmap <buffer> q'
      \ . '| nunmap <buffer> R'
