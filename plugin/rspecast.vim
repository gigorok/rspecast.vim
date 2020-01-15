if exists('g:loaded_rspecast')
  finish
endif
let g:loaded_rspecast = 1

" global vars, can be redefined
let g:rspecast#reverse = get(g:, 'rspecast#reverse', v:true)
if g:rspecast#reverse
  let g:rspec_ast_path_separator = ' < '
else
  let g:rspec_ast_path_separator = ' > '
endif
let g:rspec_ast_path_indicator = '>>'
let g:rspec_hlgroup = 'StorageClass'
let g:rspec_ast_limit = 3 " or 0 (no limit)

augroup onMove
  autocmd!
  au CursorMoved * call rspecast#RspecContext()
  au BufWritePost * call rspecast#RspecRecache()
augroup END

call rspecast#TryTcpConnect()

" command! -nargs=0 JumpLineForward call JumpLineForward()
" command! -nargs=0 JumpLineBackward call JumpLineBackward()
" nnoremap <silent> <leader>k :JumpLineForward<CR>
" nnoremap <silent> <leader>j :JumpLineBackward<CR>
