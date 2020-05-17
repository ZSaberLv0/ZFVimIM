
" ============================================================
if !exists('g:ZFVimIM_autoAddWordLen')
    let g:ZFVimIM_autoAddWordLen=3*4
endif

" ============================================================
augroup ZFVimIME_augroup
    autocmd!

    autocmd User ZFVimIM_event_OnDbInit silent

    autocmd User ZFVimIM_event_OnStart silent

    autocmd User ZFVimIM_event_OnStop silent

    " added word can be checked by g:ZFVimIM_event_OnAddWord : {
    "   'dbId' : 'add to which db',
    "   'key' : 'matched full key',
    "   'word' : 'matched word',
    " }
    autocmd User ZFVimIM_event_OnAddWord silent

    " current db can be accessed by g:ZFVimIM_db[g:ZFVimIM_dbIndex]
    autocmd User ZFVimIM_event_OnDbChange silent
augroup END

function! ZFVimIME_init()
    if !exists('s:dbInitFlag')
        let s:dbInitFlag = 1
        doautocmd User ZFVimIM_event_OnDbInit
        doautocmd User ZFVimIM_event_OnDbChange
    endif
endfunction

" ============================================================
function! ZFVimIME_toggle()
    return s:started ? ZFVimIME_stop() : ZFVimIME_start()
endfunction

if get(g:, 'ZFVimIM_keymap', 1)
    nnoremap <expr><silent> ;; ZFVimIME_keymap_toggle_n()
    inoremap <expr> ;; ZFVimIME_keymap_toggle_i()
    vnoremap <expr> ;; ZFVimIME_keymap_toggle_v()

    nnoremap <expr><silent> ;: ZFVimIME_keymap_next_n()
    inoremap <expr> ;: ZFVimIME_keymap_next_i()
    vnoremap <expr> ;: ZFVimIME_keymap_next_v()

    nnoremap <expr><silent> ;, ZFVimIME_keymap_add_n()
    inoremap <expr> ;, ZFVimIME_keymap_add_i()
    xnoremap <expr> ;, ZFVimIME_keymap_add_v()

    nnoremap <expr><silent> ;. ZFVimIME_keymap_remove_n()
    inoremap <expr> ;. ZFVimIME_keymap_remove_i()
    xnoremap <expr> ;. ZFVimIME_keymap_remove_v()
endif

function! ZFVimIME_keymap_toggle_n()
    call feedkeys("i\<c-r>=ZFVimIME_toggle()\<cr>\<esc>l", 'nt')
    return ''
endfunction
function! ZFVimIME_keymap_toggle_i()
    call feedkeys("\<c-r>=ZFVimIME_toggle()\<cr>", 'nt')
    return ''
endfunction
function! ZFVimIME_keymap_toggle_v()
    call feedkeys("\<esc>a\<c-r>=ZFVimIME_toggle()\<cr>\<esc>gv", 'nt')
    return ''
endfunction

function! ZFVimIME_keymap_next_n()
    call feedkeys("i\<c-r>=ZFVimIME_next()\<cr>\<esc>", 'nt')
    return ''
endfunction
function! ZFVimIME_keymap_next_i()
    call feedkeys("\<c-r>=ZFVimIME_next()\<cr>", 'nt')
    return ''
endfunction
function! ZFVimIME_keymap_next_v()
    call feedkeys("\<esc>a\<c-r>=ZFVimIME_next()\<cr>\<esc>gv", 'nt')
    return ''
endfunction

function! ZFVimIME_keymap_add_n()
    if !s:started
        call feedkeys("i\<c-r>=ZFVimIME_start()\<cr>\<esc>", 'nt')
    endif
    call feedkeys(":IMAdd\<space>\<c-c>q:kA", 'nt')
    return ''
endfunction
function! ZFVimIME_keymap_add_i()
    if !s:started
        call feedkeys("\<c-r>=ZFVimIME_start()\<cr>", 'nt')
    endif
    call feedkeys("\<esc>:IMAdd\<space>\<c-c>q:kA", 'nt')
    return ''
endfunction
function! ZFVimIME_keymap_add_v()
    if !s:started
        call feedkeys("\<esc>i\<c-r>=ZFVimIME_start()\<cr>\<esc>gv", 'nt')
    endif
    call feedkeys("\"ty:IMAdd\<space>\<c-r>t\<space>\<c-c>q:kA", 'nt')
    return ''
endfunction

function! ZFVimIME_keymap_remove_n()
    if !s:started
        call feedkeys("i\<c-r>=ZFVimIME_start()\<cr>\<esc>", 'nt')
    endif
    call feedkeys(":IMRemove\<space>\<c-c>q:kA", 'nt')
    return ''
endfunction
function! ZFVimIME_keymap_remove_i()
    if !s:started
        call feedkeys("\<c-r>=ZFVimIME_start()\<cr>", 'nt')
    endif
    call feedkeys("\<esc>:IMRemove\<space>\<c-c>q:kA", 'nt')
    return ''
endfunction
function! ZFVimIME_keymap_remove_v()
    if !s:started
        call feedkeys("\<esc>i\<c-r>=ZFVimIME_start()\<cr>\<esc>gv", 'nt')
    endif
    call feedkeys("\"tx:IMRemove\<space>\<c-r>t\<cr>", 'nt')
    return ''
endfunction

if get(g:, 'ZFVimIME_fixCtrlC', 1)
    " <c-c> won't fire InsertLeave, we needs this to reset userWord detection
    inoremap <c-c> <esc>
endif

function! ZFVimIME_started()
    return s:started
endfunction

function! ZFVimIME_start()
    call ZFVimIME_stop()
    doautocmd User ZFVimIM_event_OnStart
    let s:started = 1
    let ret = s:IME_start()
    return ret
endfunction

function! ZFVimIME_stop()
    if !s:started
        return ''
    endif
    let s:started = 0
    let ret = s:IME_stop()
    doautocmd User ZFVimIM_event_OnStop
    return ret
endfunction

function! ZFVimIME_next()
    if !s:started
        return ZFVimIME_start()
    endif
    call ZFVimIME_switchToIndex(g:ZFVimIM_dbIndex + 1)
    return ''
endfunction

function! ZFVimIME_switchToIndex(dbIndex)
    let dbIndex = a:dbIndex
    if dbIndex >= len(g:ZFVimIM_db) || dbIndex < 0
        let dbIndex = 0
    endif
    if dbIndex == g:ZFVimIM_dbIndex
        return ''
    endif
    let g:ZFVimIM_dbIndex = dbIndex
    call s:IME_update()
    doautocmd User ZFVimIM_event_OnDbChange
    return ''
endfunction

function! ZFVimIME_omnifunc(start, keyboard)
    return s:omnifunc(a:start, a:keyboard)
endfunction


" ============================================================
function! ZFVimIME_esc()
    if mode() != 'i'
        call feedkeys("\<esc>", 'nt')
        redraw
        return ''
    endif
    let key = "\<esc>"
    if pumvisible()
        " :help i_CTRL-U
        let key = nr2char(21)
        if pumvisible()
            let range = col('.') - 1 - s:start_column
            let key = "\<c-e>" . repeat("\<left>\<delete>", range)
        endif
        silent! call s:resetAfterInsert()
    endif
    silent! execute 'silent! return "' . key . '"'
endfunction

function! ZFVimIME_label(key)
    if mode() != 'i'
        call feedkeys(a:key, 'nt')
        redraw
        return ''
    endif
    let key = a:key
    if pumvisible()
        if key =~ '\d'
            let n = key < 1 ? 9 : key - 1
        endif
        let yes = repeat("\<down>", n). "\<c-y>"
        let omni = "\<c-r>=ZFVimIME_callOmni()\<cr>"
        let key = yes . omni
        let item = s:match_list[n]
        let s:confirmFlag = 1

        if !s:completeItemAvailable
            call add(s:userWord, item)
            if item['len'] == len(s:keyboard)
                call s:addWordFromUserWord()
                let s:userWord = []
            endif
        endif

        silent! call s:resetAfterInsert()
    endif
    silent! execute 'silent! return "' . key . '"'
endfunction

function! ZFVimIME_bracket(offset)
    let cursor = ''
    let range = col('.') - 1 - s:start_column
    let repeat_times = range / s:multibyte + a:offset
    if repeat_times
        let cursor = repeat("\<left>\<delete>", repeat_times)
    elseif repeat_times < 1
        let cursor = strpart(getline('.'), s:start_column, s:multibyte)
    endif
    return cursor
endfunction
function! ZFVimIME_page(key)
    if mode() != 'i'
        call feedkeys(a:key, 'nt')
        redraw
        return ''
    endif
    let key = a:key
    if pumvisible()
        let page = "\<c-e>\<c-r>=ZFVimIME_callOmni()\<cr>"
        if key =~ '[][]'
            let left  = (key == ']') ? "\<left>"  : ''
            let right = (key == ']') ? "\<right>" : ''
            let _ = key == ']' ? 0 : -1
            let backspace = "\<c-r>=ZFVimIME_bracket("._.")\<cr>"
            let key = "\<c-y>" . left . backspace . right
        elseif key =~ '[=.]'
            let s:pageup_pagedown = &pumheight ? 1 : 0
            let key = &pumheight ? page : "\<pagedown>"
        elseif key =~ '[-,]'
            let s:pageup_pagedown = &pumheight ? -1 : 0
            let key = &pumheight ? page : "\<pageup>"
        endif
    endif
    silent! execute 'silent! return "' . key . '"'
endfunction

function! ZFVimIME_space()
    if mode() != 'i'
        call feedkeys("\<space>", 'nt')
        redraw
        return ''
    endif
    if pumvisible()
        let s:confirmFlag = 1
        let key = "\<c-y>\<c-r>=ZFVimIME_callOmni()\<cr>"
    else
        let key = ' '
    endif
    call s:resetAfterInsert()
    silent! execute 'silent! return "' . key . '"'
endfunction

function! ZFVimIME_enter()
    if mode() != 'i'
        call feedkeys("\<cr>", 'nt')
        redraw
        return ''
    endif
    let s:omni = 0
    let key = ''
    if pumvisible()
        let key = "\<c-e>"
        let s:smart_enter = 1
    elseif s:hasLeftChar()
        let s:smart_enter = 1
        if s:seamless_positions == getpos('.')
            let s:smart_enter += 1
        endif
    else
        let s:smart_enter = 0
    endif
    if s:smart_enter == 1
        let s:seamless_positions = getpos('.')
    else
        let key = "\<cr>"
        let s:smart_enter = 0
    endif
    silent! execute 'silent! return "' . key . '"'
endfunction

function! ZFVimIME_backspace()
    if mode() != 'i'
        call feedkeys("\<bs>", 'nt')
        redraw
        return ''
    endif
    let s:omni = 0
    let key = pumvisible() ? "\<c-r>=ZFVimIME_callOmni()\<cr>" : ''
    let key = "\<bs>" . key
    silent! execute 'silent! return "' . key . '"'
endfunction

function! ZFVimIME_input(c)
    if mode() != 'i'
        call feedkeys(a:c, 'nt')
        redraw
        return ''
    endif
    return a:c . ZFVimIME_callOmni()
endfunction

function! ZFVimIME_callOmni()
    let s:omni = s:omni < 0 ? -1 : 0
    let s:keyboard = empty(s:pageup_pagedown) ? '' : s:keyboard
    let key = s:hasLeftChar() ? "\<c-x>\<c-o>\<c-r>=ZFVimIME_fixOmni()\<cr>" : ''
    silent! execute 'silent! return "' . key . '"'
endfunction

function! ZFVimIME_fixOmni()
    let s:omni = s:omni < 0 ? 0 : 1
    let key = "\<c-p>\<down>"
    let key = pumvisible() ? key : ''
    silent! execute 'silent! return "' . key . '"'
endfunction

augroup ZFVimIME_impl_toggle_augroup
    autocmd!
    autocmd User ZFVimIM_event_OnStart call s:IMEEventStart()
    autocmd User ZFVimIM_event_OnStop call s:IMEEventStop()
augroup END
function! s:IMEEventStart()
    augroup ZFVimIME_impl_augroup
        autocmd!
        autocmd InsertLeave * let s:userWord=[]
        autocmd BufEnter,CmdwinEnter * call s:IME_syncBuffer()
        autocmd CompleteDone * call s:OnCompleteDone()
    augroup END
endfunction
function! s:IMEEventStop()
    augroup ZFVimIME_impl_augroup
        autocmd!
    augroup END
endfunction

function! s:init()
    let s:started = 0
    let s:multibyte = &encoding =~ 'utf-8' ? 3 : 2
    let s:seamless_positions = []
    let s:start_column = 1
    let s:valid_keyboard = '[0-9a-z]'
    let s:valid_keys = split('abcdefghijklmnopqrstuvwxyz', '\zs')
endfunction

function! s:IME_update()
    if g:ZFVimIM_dbIndex < len(g:ZFVimIM_db)
        let b:keymap_name=g:ZFVimIM_db[g:ZFVimIM_dbIndex]['name']
    else
        let b:keymap_name='ZFVimIM'
    endif
endfunction

function! s:IME_start()
    call ZFVimIME_init()

    silent! call s:vimrcSave()
    silent! call s:vimrcSetup()
    silent! call s:setupKeymap()
    call s:IME_update()
    let b:ZFVimIME_started = 1

    let s:seamless_positions = getpos('.')

    " :h i_CTRL-^
    silent! execute 'silent! return "' . nr2char(30) . '"'
endfunction

function! s:IME_stop()
    lmapclear
    silent! call s:vimrcRestore()
    silent! call s:resetSuper()
    silent! unlet b:ZFVimIME_started
    silent! execute 'silent! return "' . nr2char(30) . '"'
endfunction

function! s:IME_syncBuffer_delay(...)
    if s:started && !get(b:, 'ZFVimIME_started', 0)
        call ZFVimIME_stop()
        call ZFVimIME_start()
    endif
    redraw!
endfunction
function! s:IME_syncBuffer()
    if s:started && !get(b:, 'ZFVimIME_started', 0)
        if has('timers')
            call timer_start(0, function('s:IME_syncBuffer_delay'))
        else
            call ZFVimIME_stop()
            call ZFVimIME_start()
        endif
    endif
endfunction

function! s:vimrcSave()
    let s:saved_omnifunc    = &omnifunc
    let s:saved_completeopt = &completeopt
    let s:saved_shortmess   = &shortmess
    let s:saved_pumheight   = &pumheight
    let s:saved_lazyredraw  = &lazyredraw
endfunction

function! s:vimrcSetup()
    set omnifunc=ZFVimIME_omnifunc
    set completeopt=menuone
    set shortmess+=c
    set pumheight=10
    set nolazyredraw
endfunction

function! s:vimrcRestore()
    let &omnifunc    = s:saved_omnifunc
    let &completeopt = s:saved_completeopt
    let &shortmess   = s:saved_shortmess
    let &pumheight   = s:saved_pumheight
    let &lazyredraw  = s:saved_lazyredraw
endfunction

function! s:setupKeymap()
    for char in s:valid_keys
        silent! execute 'lnoremap<silent><buffer> ' . char . " <c-r>=ZFVimIME_input('" . char . "')<cr>"
    endfor

    let common_punctuations = split('] [ = -')
    for _ in common_punctuations
        if _ !~ s:valid_keyboard
            silent! execute 'lnoremap<buffer><expr> '._.' ZFVimIME_page("'._.'")'
        endif
    endfor

    let common_labels = range(10)
    for _ in common_labels
        silent! execute 'lnoremap<buffer><expr> '._.' ZFVimIME_label("'._.'")'
    endfor

    lnoremap <silent><buffer> <expr> <bs>    ZFVimIME_backspace()
    lnoremap <silent><buffer> <expr> <esc>   ZFVimIME_esc()
    lnoremap <silent><buffer> <expr> <cr>    ZFVimIME_enter()
    lnoremap <silent><buffer> <expr> <space> ZFVimIME_space()
endfunction

function! s:resetSuper()
    silent! call s:resetBeforeAnything()
    silent! call s:resetBeforeOmni()
    silent! call s:resetAfterInsert()
endfunction

function! s:resetBeforeAnything()
    let s:keyboard = ''
    let s:omni = 0
    let s:smart_enter = 0
    let s:popup_list = []
endfunction

function! s:resetBeforeOmni()
endfunction

function! s:resetAfterInsert()
    let s:match_list = []
    let s:pageup_pagedown = 0
endfunction

function! s:omniCache()
    let results = []
    if s:pageup_pagedown != 0
        let length = len(s:match_list)
        if length > &pumheight
            let page = s:pageup_pagedown * &pumheight
            let partition = page ? page : length+page
            let B = s:match_list[partition :]
            let A = s:match_list[: partition-1]
            let results = B + A
        endif
    endif
    return results
endfunction

function! s:getSeamless(cursor_positions)
    if empty(s:seamless_positions)
                \|| s:seamless_positions[0] != a:cursor_positions[0]
                \|| s:seamless_positions[1] != a:cursor_positions[1]
                \|| s:seamless_positions[3] != a:cursor_positions[3]
        return -1
    endif
    let current_line = getline(a:cursor_positions[1])
    let seamless_column = s:seamless_positions[2]-1
    let len = a:cursor_positions[2]-1 - seamless_column
    let snip = strpart(current_line, seamless_column, len)
    if empty(len(snip))
        return -1
    endif
    for char in split(snip, '\zs')
        if char !~ s:valid_keyboard
            return -1
        endif
    endfor
    return seamless_column
endfunction

function! s:hasLeftChar()
    let key = 0
    let one_byte_before = getline('.')[col('.')-2]
    if one_byte_before =~ '\s' || empty(one_byte_before)
        let key = 0
    elseif one_byte_before =~# s:valid_keyboard
        let key = 1
    endif
    return key
endfunction

function! s:omnifunc(start, keyboard)
    let valid_keyboard = s:valid_keyboard
    if a:start
        let cursor_positions = getpos('.')
        let start_row = cursor_positions[1]
        let start_column = cursor_positions[2]-1
        let current_line = getline(start_row)
        let before = current_line[start_column-1]
        let seamless_column = s:getSeamless(cursor_positions)
        if seamless_column < 0
            let s:seamless_positions = []
            let last_seen_bslash_column = copy(start_column)
            let last_seen_nonsense_column = copy(start_column)
            let all_digit = 1
            while start_column
                if before =~# valid_keyboard
                    let start_column -= 1
                    if before !~# "[0-9']"
                        let last_seen_nonsense_column = start_column
                        let all_digit = 0
                    endif
                elseif before == '\'
                    return last_seen_bslash_column
                else
                    break
                endif
                let before = current_line[start_column-1]
            endwhile
            if all_digit < 1 && current_line[start_column] =~ '\d'
                let start_column = last_seen_nonsense_column
            endif
        else
            let start_column = seamless_column
        endif
        let len = cursor_positions[2]-1 - start_column
        let keyboard = strpart(current_line, start_column, len)
        if s:keyboard !~ '\S\s\S'
            let s:keyboard = keyboard
        endif
        let s:start_column = start_column
        return start_column
    else
        if s:omni < 0
            return []
        endif
        let results = s:omniCache()
        if empty(results)
            silent! call s:resetBeforeOmni()
        else
            return s:popupMenuList(results)
        endif
        let keyboard = a:keyboard
        if !empty(str2nr(keyboard))
            let keyboard = get(split(s:keyboard), 0)
        endif
        if empty(keyboard) || keyboard !~ valid_keyboard
            return []
        endif
        if empty(results)
            let results = ZFVimIM_complete(keyboard)
        endif
        return s:popupMenuList(results)
    endif
endfunction

function! s:popupMenuList(complete)
    let s:match_list = a:complete
    if empty(a:complete) || type(a:complete) != type([])
        return []
    endif
    let label = 1
    let s:popup_list = []
    for item in s:match_list
        " :h complete-items
        let complete_items = {}
        let labelstring = (label == 10 ? '0' : label)
        let labelstring = printf('%2s ', labelstring)
        let left = strpart(s:keyboard, item['len'])
        let complete_items['abbr'] = labelstring . item['word'] . left
        if item['type'] == 'sentence'
            let menu = ''
            for word in item['sentenceList']
                if !empty(menu)
                    let menu .= ' '
                endif
                let menu .= word['key']
            endfor
            let complete_items['menu'] = menu
        else
            let complete_items['menu'] = item['key']
        endif
        if item['dbId'] != g:ZFVimIM_db[g:ZFVimIM_dbIndex]['dbId']
            let complete_items['menu'] .= '  <' . ZFVimIM_dbForId(item['dbId'])['name'] . '>'
        endif
        if get(g:, 'ZFVimIME_DEBUG', 0)
            let complete_items['menu'] .= '  (' . item['type'] . ')'
        endif
        let complete_items['dup'] = 1
        let complete_items['word'] = item['word'] . left
        if s:completeItemAvailable
            let complete_items['info'] = json_encode(item)
        endif
        call add(s:popup_list, complete_items)
        let label += 1
    endfor

    let &completeopt = 'menuone'
    let &pumheight = 10
    return s:popup_list
endfunction


function! s:addWord(dbId, key, word)
    if a:dbId == g:ZFVimIM_db[g:ZFVimIM_dbIndex]['dbId']
        call ZFVimIM_wordAdd(a:word, a:key)
    endif

    let g:ZFVimIM_event_OnAddWord = {
                \   'dbId' : a:dbId,
                \   'key' : a:key,
                \   'word' : a:word,
                \ }
    doautocmd User ZFVimIM_event_OnAddWord
endfunction

let s:completeItemAvailable = (exists('v:completed_item') && exists('*json_encode'))
let s:confirmFlag = 0
let s:userWord=[]
function! s:OnCompleteDone()
    if !s:confirmFlag
        return
    endif
    let s:confirmFlag = 0
    if !s:completeItemAvailable
        return
    endif
    try
        let item = json_decode(v:completed_item['info'])
    catch
        let item = ''
    endtry
    if empty(item)
        let s:userWord = []
        return
    endif

    if item['type'] == 'sentence'
        for word in item['sentenceList']
            call s:addWord(item['dbId'], word['key'], word['word'])
        endfor
        let s:userWord = []
        return
    endif

    call add(s:userWord, item)

    if item['len'] == len(s:keyboard)
        call s:addWordFromUserWord()
        let s:userWord = []
    endif
endfunction
function! s:addWordFromUserWord()
    if !empty(s:userWord)
        let sentenceKey = ''
        let sentenceWord = ''
        let hasOtherDb = 0
        let dbIdCur = g:ZFVimIM_db[g:ZFVimIM_dbIndex]['dbId']
        for word in s:userWord
            if !hasOtherDb
                let hasOtherDb = (dbIdCur != word['dbId'])
            endif
            let sentenceKey .= word['key']
            let sentenceWord .= word['word']
        endfor
        if !hasOtherDb && len(sentenceWord) <= g:ZFVimIM_autoAddWordLen
            call s:addWord(s:userWord[0]['dbId'], sentenceKey, sentenceWord)
        else
            for word in s:userWord
                call s:addWord(word['dbId'], word['key'], word['word'])
            endfor
        endif
    endif
endfunction


silent! call s:init()
silent! call s:resetSuper()

