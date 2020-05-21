
" ============================================================
if !exists('g:ZFVimIM_autoAddWordLen')
    let g:ZFVimIM_autoAddWordLen=3*4
endif
" function(userWords)
" userWords: see ZFVimIM_complete
" return: 1 if need add word
if !exists('g:ZFVimIM_autoAddWordChecker')
    let g:ZFVimIM_autoAddWordChecker=[]
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
    call ZFVimIME_toggle()
    redraw
    return ''
endfunction
function! ZFVimIME_keymap_toggle_i()
    call ZFVimIME_toggle()
    redraw
    return ''
endfunction
function! ZFVimIME_keymap_toggle_v()
    call ZFVimIME_toggle()
    redraw
    return ''
endfunction

function! ZFVimIME_keymap_next_n()
    call ZFVimIME_next()
    redraw
    return ''
endfunction
function! ZFVimIME_keymap_next_i()
    call ZFVimIME_next()
    redraw
    return ''
endfunction
function! ZFVimIME_keymap_next_v()
    call ZFVimIME_next()
    redraw
    return ''
endfunction

function! ZFVimIME_keymap_add_n()
    if !s:started
        call ZFVimIME_start()
    endif
    call feedkeys(":IMAdd\<space>\<c-c>q:kA", 'nt')
    return ''
endfunction
function! ZFVimIME_keymap_add_i()
    if !s:started
        call ZFVimIME_start()
    endif
    call feedkeys("\<esc>:IMAdd\<space>\<c-c>q:kA", 'nt')
    return ''
endfunction
function! ZFVimIME_keymap_add_v()
    if !s:started
        call ZFVimIME_start()
    endif
    call feedkeys("\"ty:IMAdd\<space>\<c-r>t\<space>\<c-c>q:kA", 'nt')
    return ''
endfunction

function! ZFVimIME_keymap_remove_n()
    if !s:started
        call ZFVimIME_start()
    endif
    call feedkeys(":IMRemove\<space>\<c-c>q:kA", 'nt')
    return ''
endfunction
function! ZFVimIME_keymap_remove_i()
    if !s:started
        call ZFVimIME_start()
    endif
    call feedkeys("\<esc>:IMRemove\<space>\<c-c>q:kA", 'nt')
    return ''
endfunction
function! ZFVimIME_keymap_remove_v()
    if !s:started
        call ZFVimIME_start()
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

function! ZFVimIME_toggle()
    if s:started
        call ZFVimIME_stop()
    else
        call ZFVimIME_start()
    endif
endfunction

function! ZFVimIME_start()
    call ZFVimIME_stop()
    doautocmd User ZFVimIM_event_OnStart
    if mode() == 'i'
        " :h i_CTRL-^
        " when enabled first time,
        " just setting iminsert seems not work,
        " reason unknown
        call feedkeys(nr2char(30), 'nt')
    endif
    let s:started = 1
    let &iminsert = s:started
    call s:IME_start()
endfunction

function! ZFVimIME_stop()
    if !s:started
        return ''
    endif
    let s:started = 0
    let &iminsert = s:started
    call s:IME_stop()
    doautocmd User ZFVimIM_event_OnStop
endfunction

function! ZFVimIME_next()
    if !s:started
        return ZFVimIME_start()
    endif
    call ZFVimIME_switchToIndex(g:ZFVimIM_dbIndex + 1)
endfunction

function! ZFVimIME_switchToIndex(dbIndex)
    let dbIndex = a:dbIndex
    if dbIndex >= len(g:ZFVimIM_db) || dbIndex < 0
        let dbIndex = 0
    endif
    if dbIndex == g:ZFVimIM_dbIndex
        return
    endif
    let g:ZFVimIM_dbIndex = dbIndex
    call s:IME_update()
    doautocmd User ZFVimIM_event_OnDbChange
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
    if pumvisible()
        let range = col('.') - 1 - s:start_column
        let key = "\<c-e>" . repeat("\<bs>", range)
        call s:resetAfterInsert()
    else
        let key = "\<esc>"
    endif
    call feedkeys(key, 'nt')
    return ''
endfunction

function! ZFVimIME_label(n)
    if mode() != 'i'
        call feedkeys(a:n, 'nt')
        redraw
        return ''
    endif
    if pumvisible()
        let n = a:n < 1 ? 9 : a:n - 1
        let key = repeat("\<down>", n) . "\<c-y>\<c-r>=ZFVimIME_callOmni()\<cr>"

        let s:confirmFlag = 1
        if !s:completeItemAvailable
            let item = s:match_list[n]
            call add(s:userWord, item)
            if item['len'] == len(s:keyboard)
                call s:addWordFromUserWord()
                let s:userWord = []
            endif
        endif
        call s:resetAfterInsert()
    else
        let key = a:key
    endif
    call feedkeys(key, 'nt')
    return ''
endfunction

function! ZFVimIME_pageUp(key)
    if mode() != 'i'
        call feedkeys(a:key, 'nt')
        redraw
        return ''
    endif
    if pumvisible()
        let page = "\<c-e>\<c-r>=ZFVimIME_callOmni()\<cr>"
        let s:pageup_pagedown = &pumheight ? -1 : 0
        let key = &pumheight ? page : "\<pageup>"
    else
        let key = a:key
    endif
    call feedkeys(key, 'nt')
    return ''
endfunction
function! ZFVimIME_pageDown(key)
    if mode() != 'i'
        call feedkeys(a:key, 'nt')
        redraw
        return ''
    endif
    if pumvisible()
        let page = "\<c-e>\<c-r>=ZFVimIME_callOmni()\<cr>"
        let s:pageup_pagedown = &pumheight ? 1 : 0
        let key = &pumheight ? page : "\<pagedown>"
    else
        let key = a:key
    endif
    call feedkeys(key, 'nt')
    return ''
endfunction

" note, this func must invoked as `<c-r>=`
" to ensure `<c-y>` actually transformed popup word
function! ZFVimIME_choose_fix(offset)
    let words = split(strpart(getline('.'), s:start_column, col('.') - s:start_column), '\ze')
    return repeat("\<bs>", len(words) - 1)
endfunction
function! ZFVimIME_chooseL(key)
    if mode() != 'i'
        call feedkeys(a:key, 'nt')
        redraw
        return ''
    endif
    if pumvisible()
        let key = "\<c-y>\<c-r>=ZFVimIME_choose_fix(0)\<cr>"
        call s:resetAfterInsert()
    else
        let key = a:key
    endif
    call feedkeys(key, 'nt')
    return ''
endfunction
function! ZFVimIME_chooseR(key)
    if mode() != 'i'
        call feedkeys(a:key, 'nt')
        redraw
        return ''
    endif
    if pumvisible()
        let key = "\<c-y>\<left>\<c-r>=ZFVimIME_choose_fix(-1)\<cr>\<right>"
        call s:resetAfterInsert()
    else
        let key = a:key
    endif
    call feedkeys(key, 'nt')
    return ''
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
    call feedkeys(key, 'nt')
    return ''
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
    call s:resetAfterInsert()
    call feedkeys(key, 'nt')
    return ''
endfunction

function! ZFVimIME_backspace()
    if mode() != 'i'
        call feedkeys("\<bs>", 'nt')
        redraw
        return ''
    endif
    let s:omni = 0
    let key = "\<bs>"
    if pumvisible()
        let key .= "\<c-r>=ZFVimIME_callOmni()\<cr>"
    endif
    call s:resetAfterInsert()
    call feedkeys(key, 'nt')
    return ''
endfunction

function! ZFVimIME_input()
    if mode() != 'i'
        redraw
        return ''
    endif
    return ZFVimIME_callOmni()
endfunction

function! ZFVimIME_callOmni()
    let s:omni = s:omni < 0 ? -1 : 0
    let s:keyboard = empty(s:pageup_pagedown) ? '' : s:keyboard
    let key = s:hasLeftChar() ? "\<c-x>\<c-o>\<c-r>=ZFVimIME_fixOmni()\<cr>" : ''
    execute 'return "' . key . '"'
endfunction

function! ZFVimIME_fixOmni()
    let s:omni = s:omni < 0 ? 0 : 1
    let key = pumvisible() ? "\<c-p>\<down>" : ''
    execute 'return "' . key . '"'
endfunction

augroup ZFVimIME_impl_toggle_augroup
    autocmd!
    autocmd User ZFVimIM_event_OnStart call s:IMEEventStart()
    autocmd User ZFVimIM_event_OnStop call s:IMEEventStop()
augroup END
function! s:IMEEventStart()
    augroup ZFVimIME_impl_augroup
        autocmd!
        autocmd InsertLeave * call s:OnInsertLeave()
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

    call s:vimrcSave()
    call s:vimrcSetup()
    call s:setupKeymap()
    call s:IME_update()
    let b:ZFVimIME_started = 1

    let s:seamless_positions = getpos('.')
endfunction

function! s:IME_stop()
    lmapclear
    call s:vimrcRestore()
    call s:resetState()
    if exists('b:ZFVimIME_started')
        unlet b:ZFVimIME_started
    endif
endfunction

function! s:IME_syncBuffer_action()
    call ZFVimIME_stop()
    call ZFVimIME_start()
    set iminsert=1
endfunction
function! s:IME_syncBuffer_delay(...)
    if s:started && !get(b:, 'ZFVimIME_started', 0)
        call s:IME_syncBuffer_action()
    endif
    redraw!
endfunction
function! s:IME_syncBuffer()
    if s:started && !get(b:, 'ZFVimIME_started', 0)
        if has('timers')
            call timer_start(0, function('s:IME_syncBuffer_delay'))
        else
            call s:IME_syncBuffer_action()
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
    for c in s:valid_keys
        execute 'lnoremap<silent><buffer> ' . c . ' ' . c . '<c-r>=ZFVimIME_input()<cr>'
    endfor

    for c in ['-']
        if c !~ s:valid_keyboard
            execute 'lnoremap<buffer><expr> ' . c . ' ZFVimIME_pageUp("' . c . '")'
        endif
    endfor
    for c in ['=']
        if c !~ s:valid_keyboard
            execute 'lnoremap<buffer><expr> ' . c . ' ZFVimIME_pageDown("' . c . '")'
        endif
    endfor

    for c in ['[']
        if c !~ s:valid_keyboard
            execute 'lnoremap<buffer><expr> ' . c . ' ZFVimIME_chooseL("' . c . '")'
        endif
    endfor
    for c in [']']
        if c !~ s:valid_keyboard
            execute 'lnoremap<buffer><expr> ' . c . ' ZFVimIME_chooseR("' . c . '")'
        endif
    endfor

    for n in range(10)
        execute 'lnoremap<buffer><expr> ' . n . ' ZFVimIME_label("' . n . '")'
    endfor

    lnoremap <silent><buffer> <expr> <bs>    ZFVimIME_backspace()
    lnoremap <silent><buffer> <expr> <esc>   ZFVimIME_esc()
    lnoremap <silent><buffer> <expr> <cr>    ZFVimIME_enter()
    lnoremap <silent><buffer> <expr> <space> ZFVimIME_space()
endfunction

function! s:resetState()
    call s:resetAfterInsert()
    let s:keyboard = ''
    let s:omni = 0
    let s:smart_enter = 0
    let s:userWord = []
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
    for c in split(snip, '\zs')
        if c !~ s:valid_keyboard
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
        if !empty(results)
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
    let popup_list = []
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
        call add(popup_list, complete_items)
        let label += 1
    endfor

    let &completeopt = 'menuone'
    let &pumheight = 10
    return popup_list
endfunction

function! s:OnInsertLeave()
    call s:resetState()
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
            call s:addWord(word['dbId'], word['key'], word['word'])

            if !hasOtherDb
                let hasOtherDb = (dbIdCur != word['dbId'])
            endif
            let sentenceKey .= word['key']
            let sentenceWord .= word['word']
        endfor

        let needAdd = 0
        if !empty(g:ZFVimIM_autoAddWordChecker)
            let needAdd = 1
            for Checker in g:ZFVimIM_autoAddWordChecker
                if ZFJobFuncCallable(Checker)
                    let needAdd = ZFJobFuncCall(Checker, [s:userWord])
                    if !needAdd
                        break
                    endif
                endif
            endfor
        else
            if !hasOtherDb
                        \ && len(s:userWord) > 1
                        \ && len(sentenceWord) <= g:ZFVimIM_autoAddWordLen
                let needAdd = 1
            endif
        endif
        if needAdd
            call s:addWord(s:userWord[0]['dbId'], sentenceKey, sentenceWord)
        endif
    endif
endfunction

call s:init()
call s:resetState()

