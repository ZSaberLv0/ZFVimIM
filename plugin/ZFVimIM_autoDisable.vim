
" ['enableCallback', 'disableCallback']
let s:callback = []
augroup ZFVimIM_autoDisable_augroup
    autocmd!
    autocmd User ZFVimIM_event_OnStart for cb in s:callback | let Fn = function(cb[1]) | silent! call Fn() | endfor
    autocmd User ZFVimIM_event_OnStop for cb in s:callback | let Fn = function(cb[0]) | silent! call Fn() | endfor
augroup END


" ============================================================

" coc
function! s:coc_enable()
    if get(g:, 'ZFVimIM_autoDisable_coc', 1) && exists(':CocEnable')
        call coc#config('suggest.autoTrigger', 'always')
        CocEnable
    endif
endfunction
function! s:coc_disable()
    if get(g:, 'ZFVimIM_autoDisable_coc', 1) && exists(':CocEnable')
        call coc#config('suggest.autoTrigger', 'none')
        CocDisable
    endif
endfunction
call add(s:callback, ['s:coc_enable', 's:coc_disable'])

" deoplete
function! s:deoplete_enable()
    if get(g:, 'ZFVimIM_autoDisable_deoplete', 1) && exists('*deoplete#enable')
        call deoplete#enable()
    endif
endfunction
function! s:deoplete_disable()
    if get(g:, 'ZFVimIM_autoDisable_deoplete', 1) && exists('*deoplete#enable')
        call deoplete#disable()
    endif
endfunction
call add(s:callback, ['s:deoplete_enable', 's:deoplete_disable'])

" ncm2
function! s:ncm2_enable()
    if get(g:, 'ZFVimIM_autoDisable_ncm2', 1) && exists('*ncm2#enable_for_buffer')
        call ncm2#enable_for_buffer()
    endif
endfunction
function! s:ncm2_disable()
    if get(g:, 'ZFVimIM_autoDisable_ncm2', 1) && exists('*ncm2#enable_for_buffer')
        call ncm2#disable_for_buffer()
    endif
endfunction
call add(s:callback, ['s:ncm2_enable', 's:ncm2_disable'])

" ycm
function! s:ycm_enable()
    if get(g:, 'ZFVimIM_autoDisable_ycm', 1) && exists(':YcmCompleter')
        let g:ycm_auto_trigger = 1
    endif
endfunction
function! s:ycm_disable()
    if get(g:, 'ZFVimIM_autoDisable_ycm', 1) && exists(':YcmCompleter')
        let g:ycm_auto_trigger = 0
    endif
endfunction
call add(s:callback, ['s:ycm_enable', 's:ycm_disable'])

