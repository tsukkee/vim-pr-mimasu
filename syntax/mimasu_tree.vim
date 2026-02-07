if exists('b:current_syntax')
  finish
endif

syntax match MimasuHeader /\%1l.*/
syntax match MimasuHeader /\%2l.*/
syntax match MimasuSeparator /^─\+$/

syntax match MimasuDirIcon /[▾▸]/ contained
syntax match MimasuDirName /[▾▸] .\+\// contains=MimasuDirIcon

syntax match MimasuFileAdditions /+\d\+/ contained
syntax match MimasuFileDeletions /-\d\+/ contained
syntax match MimasuFileChanges /\[+\?\d*\s*-\?\d*\]/ contains=MimasuFileAdditions,MimasuFileDeletions

hi default link MimasuHeader Title
hi default link MimasuSeparator Comment
hi default link MimasuDirIcon Special
hi default link MimasuDirName Directory
hi default link MimasuFileAdditions DiffAdd
hi default link MimasuFileDeletions DiffDelete

let b:current_syntax = 'mimasu_tree'
