if exists('g:loaded_mimasu')
  finish
endif
let g:loaded_mimasu = 1

let g:mimasu_sidebar_width = get(g:, 'mimasu_sidebar_width', 40)
let g:mimasu_sidebar_position = get(g:, 'mimasu_sidebar_position', 'topleft vertical')
let g:mimasu_fold_icons = get(g:, 'mimasu_fold_icons', ['▾', '▸'])

command! Mimasu call mimasu#open()
command! MimasuClose call mimasu#close()
