if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal buftype=acwrite
setlocal bufhidden=wipe
setlocal nobuflisted
setlocal noswapfile
setlocal syntax=markdown

augroup mimasu_comment
  autocmd! * <buffer>
  autocmd BufWriteCmd <buffer> call mimasu#review#submit()
augroup END

nnoremap <buffer> <silent> q <Cmd>call mimasu#review#cancel()<CR>

let b:undo_ftplugin = 'setlocal buftype< bufhidden< buflisted< swapfile<'
      \ . '| autocmd! mimasu_comment * <buffer>'
      \ . '| nunmap <buffer> q'
