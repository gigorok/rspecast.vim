" local vars
let s:ns_id = nvim_create_namespace('rspec_ast')
let s:recache = v:true
let s:channel_id = 0
let s:jump_lines = []

function! rspecast#RspecRecache()
  let s:recache = v:true
  " update ast now (w/o moving of cursor)
  call rspecast#RspecContext()
endfunction

function! JumpLineForward()
  let l:jump_line = s:jump_lines[0]['first_line']
  if line('.') == l:jump_line && len(s:jump_lines) > 1
    let l:jump_line = s:jump_lines[1]['first_line']
  endif
  execute "normal! " . l:jump_line . "gg"
endfunction

function! JumpLineBackward()
  let l:jump_line = s:jump_lines[0]['last_line']
  if line('.') == l:jump_line && len(s:jump_lines) > 1
    let l:jump_line = s:jump_lines[1]['last_line']
  endif
  execute "normal! " . l:jump_line . "gg"
endfunction

function! BuildRspecPath(rspec_path)
  let l:data = []
  let l:list = a:rspec_path
  let l:reverse_list = reverse(copy(a:rspec_path))
  if g:rspecast#reverse
    " TODO: does copy is important here?
    let l:list = l:reverse_list
  endif

  " store jump lines
  let s:jump_lines = []
  for s in l:reverse_list
    let s:jump_lines += [ {
          \ 'first_line': s['first_line'],
          \ 'last_line': s['last_line']
          \ } ]
  endfor

  for s in l:list[0:g:rspec_ast_limit-1]
    let l:type = get(s, 'type')
    let l:value = get(s, 'value')
    let l:first_line = get(s, 'first_line')
    let l:last_line = get(s, 'last_line')
    let l:total_lines = l:last_line - l:first_line + 1 " include first_line
    let l:data += [printf('(%.1s) %s [%d..%d | %d]', l:type, l:value, l:first_line, l:last_line, l:total_lines)]
  endfor
  if g:rspec_ast_limit != -1 && len(a:rspec_path) > len(l:data)
    return printf('{%d of %d}: %s ...', len(l:data), len(a:rspec_path), join(l:data, g:rspec_ast_path_separator))
  else
    return printf('{%d}: %s', len(a:rspec_path), join(l:data, g:rspec_ast_path_separator))
  endif
endfunction

function! DisplayRspecAstAsVirtual(rspec_path)
  call nvim_buf_clear_namespace(0, s:ns_id, 0, -1) " clear whole buffer

  if len(a:rspec_path) > 0
    let l:v_text = printf('%s %s', g:rspec_ast_path_indicator, BuildRspecPath(a:rspec_path))
    " let l:y = line('w0')-1
    let l:y = line('.')-1
    call nvim_buf_set_virtual_text(0, s:ns_id, l:y, [[l:v_text, g:rspec_hlgroup]], {})
  endif
endfunction

function! s:MyHandler(_channel_id, data, event)
  let eof = (a:data == [''])
  if !eof && IsApplicable()
    let l:json = a:data[0]
    try
      let l:rspec_path = json_decode(l:json)
      " if response fit to current buffer
      if expand('%:p') == l:rspec_path['file_path']
        call DisplayRspecAstAsVirtual(l:rspec_path['payload'])
      endif
      " when receive invalid json do nothing
    catch /E474/
    endtry
    let s:recache = v:false
  endif
endfunction

function! OnDeamonExit(job_id, exit_code, event)
  " event = exit
  echom a:job_id . ' exited with code ' . a:exit_code . '!'
endfunction

function! OnDeamonStarted(job_id, data, event)
  " pass v:false to prevent starting again
  call rspecast#TryTcpConnect(v:false)
endfunction

function! TcpConnect()
  return sockconnect('tcp', 'localhost:8888', {'on_data': function('s:MyHandler')})
endfunction

" TODO: change on_stderr to something better
function! StartTcpServer()
  let l:callbacks = {
        \ 'on_stderr': function('OnDeamonStarted'),
        \ 'detach': 1,
        \ 'on_exit': function('OnDeamonExit')
        \ }
  call jobstart('rspecast', l:callbacks)
endfunction

function! rspecast#TryTcpConnect(...)
  try
    let s:channel_id = TcpConnect()
    echom 'Successfully connected to TCP socket.'
  catch
    if get(a:, 1, v:true)
      echom 'Starting of TCP server...'
      call StartTcpServer()
    endif
  endtry
endfunction

function! rspecast#RspecContext() abort
  if IsApplicable()
    if s:channel_id
      call chansend(s:channel_id, SocketPayload())
      " call chanclose(s:channel_id)
    else
      echom 'bad socket connection!'
      " call rspecast#TryTcpConnect()
    endif
  endif
endfunction

function! SocketPayload()
  let l:json = json_encode({
        \ 'file_path': expand('%:p'),
        \ 'line_no': line('.'),
        \ 'recache': s:recache
        \ })
  return l:json . "\n"
endfunction

function! IsApplicable()
  return &filetype ==# 'ruby' && match(expand('%:t'), '_spec\.rb') != -1
endfunction
