
" ============================================================
if !exists('g:ZFVimIM_predictLimitWhenMatch')
    let g:ZFVimIM_predictLimitWhenMatch = 5
endif
if !exists('g:ZFVimIM_predictLimit')
    let g:ZFVimIM_predictLimit = 10
endif

if !exists('g:ZFVimIM_cachePath')
    let g:ZFVimIM_cachePath = get(g:, 'zf_vim_cache_path', $HOME . '/.vim_cache')
endif

" db : [
"   { // name,dbMap,dbKeyMap,dbEdit
"     'name' : 'name of the db',
"     'dbMap' : {
"       'a' : [
"         {
"           'word' : '啊',
"           'count' : 123,
"         },
"         {
"           'word' : '阿',
"           'count' : 0,
"         },
"       ],
"       'ai' : [
"         {
"           'word' : '爱',
"           'count' : 123,
"         },
"         {
"           'word' : '哀',
"           'count' : 0,
"         },
"       ],
"       'ceshi' : [
"         {
"           'word' : '测试',
"           'count' : 123,
"         },
"       ],
"     },
"     'dbKeyMap' : {
"       'a' : {
"         g:ZFVimIM_dbHasWord : '', <= an empty item to mark this node has word
"         'i' : {
"           g:ZFVimIM_dbHasWord : '',
"         },
"       },
"       'c' : {
"         'e' : {
"           's' : {
"             'h' : {
"               'i' : {
"                 g:ZFVimIM_dbHasWord : '',
"               },
"             },
"           },
"         },
"       },
"     },
"     'dbEdit' : [
"       {
"         'action' : 'add/remove/reorder',
"         'key' : 'key',
"         'word' : 'word',
"       },
"       ...
"     ],
"   },
"   ...
" ]
let g:ZFVimIM_dbHasWord = '@@'
if !exists('g:ZFVimIM_db')
    let g:ZFVimIM_db = []
endif
let g:ZFVimIM_dbIndex = 0

" ============================================================
augroup ZFVimIM_event_OnUpdateDb_augroup
    autocmd!
    autocmd User ZFVimIM_event_OnUpdateDb silent! echo ''
augroup END

" ============================================================
function! ZFVimIM_dbInit(option)
    let db = extend({
                \   'name' : 'db' . g:ZFVimIM_dbIndex,
                \   'dbMap' : {},
                \   'dbKeyMap' : {},
                \   'dbEdit' : [],
                \ }, a:option)
    call add(g:ZFVimIM_db, db)
    return db
endfunction

function! ZFVimIM_dbLoad(db, dbFile, ...)
    call s:dbLoad(a:db, a:dbFile, get(a:, 1, ''))
endfunction
function! ZFVimIM_dbSave(db, dbFile, ...)
    call s:dbSave(a:db, a:dbFile, get(a:, 1, ''))
endfunction
function! ZFVimIM_dbClear(db)
    call s:dbClear(a:db)
endfunction

function! ZFVimIM_dbEditApply(db, dbEdit)
    call s:dbEditApply(a:db, a:dbEdit)
endfunction

function! ZFVimIM_wordAdd(word, key)
    call s:dbEdit('add', a:word, a:key)
endfunction
command! -nargs=+ IMAdd :call ZFVimIM_wordAdd(<f-args>)

function! ZFVimIM_wordRemove(word, ...)
    call s:dbEditWildKey('remove', a:word, get(a:, 1, ''))
endfunction
command! -nargs=+ IMRemove :call ZFVimIM_wordRemove(<f-args>)

function! ZFVimIM_wordReorder(word, ...)
    call s:dbEditWildKey('reorder', a:word, get(a:, 1, ''))
endfunction
command! -nargs=+ IMReorder :call ZFVimIM_wordReorder(<f-args>)

function! ZFVimIM_wordIndex(wordList, word)
    for i in range(len(a:wordList))
        if a:wordList[i]['word'] == a:word
            return i
        endif
    endfor
    return -1
endfunction

function! s:wordListUpdate(word1, word2)
    return (a:word2['count'] - a:word1['count'])
endfunction
function! ZFVimIM_wordListUpdate(wordList)
    call sort(a:wordList, function('s:wordListUpdate'))
endfunction

" return : [
"   {
"     'len' : 'match count in key',
"     'key' : 'matched full key',
"     'word' : 'matched word',
"     'type' : 'type of completion: sentence/match/predict',
"     'sentenceList' : [ // for sentence type only, list of word that complete as sentence
"       {
"         'key' : '',
"         'word' : '',
"       },
"     ],
"   },
"   ...
" ]
function! ZFVimIM_complete(key)
    return s:complete(a:key)
endfunction

" ============================================================
function! s:complete(key)
    if empty(a:key) || g:ZFVimIM_dbIndex >= len(g:ZFVimIM_db)
        return []
    endif
    let key = a:key
    let keyLen = len(key)
    let dbMap = g:ZFVimIM_db[g:ZFVimIM_dbIndex]['dbMap']

    " sentence
    let sentenceRet = []
    let sentence = {
                \   'len' : 0,
                \   'key' : '',
                \   'word' : '',
                \   'type' : 'sentence',
                \   'sentenceList' : [],
                \ }
    if s:sentence(sentence, dbMap, key, keyLen) > 1
        call add(sentenceRet, sentence)
    endif

    " predict
    let predictRet = []
    if g:ZFVimIM_predictLimit != 0
        let predictPrefix = ''
        let predictDb = g:ZFVimIM_db[g:ZFVimIM_dbIndex]['dbKeyMap']
        let i = 0
        while i < keyLen
            let c = key[i]
            if !exists('predictDb[c]')
                if i == 0
                    let predictDb = {}
                endif
                break
            endif
            let predictPrefix .= c
            let predictDb = predictDb[c]
            let i += 1
        endwhile
        if !empty(predictDb)
            call s:predict(predictRet, len(predictRet), dbMap, len(predictPrefix), predictPrefix, predictDb)
        endif
    endif

    " exact match
    let matchRet = []
    let matchKeyList = []
    let i = 0
    while i < keyLen
        let i += 1
        let sub = strpart(key, 0, i)
        if exists('dbMap[sub]')
            call add(matchKeyList, sub)
        endif
    endwhile
    let i = len(matchKeyList) - 1
    while i >= 0
        let k = matchKeyList[i]
        for w in dbMap[k]
            call add(matchRet, {
                        \   'len' : len(k),
                        \   'key' : k,
                        \   'word' : w['word'],
                        \   'type' : 'match',
                        \ })
        endfor
        let i -= 1
    endwhile

    " limit predict if has match
    if len(sentenceRet) + len(matchRet) >= 5 && len(predictRet) > g:ZFVimIM_predictLimitWhenMatch
        call remove(predictRet, g:ZFVimIM_predictLimitWhenMatch, len(predictRet) - 1)
    endif

    " result
    let ret = []
    " sentence always first
    call extend(ret, sentenceRet)
    " exact match should placed first
    let iExactMatch = 0
    for i in range(len(matchRet))
        if matchRet[i]['len'] == keyLen
            let iExactMatch = i + 1
        endif
    endfor
    if iExactMatch > 0
        execute 'call extend(ret, matchRet[0:' . (iExactMatch-1) . '])'
        execute 'let matchRet = matchRet[' . iExactMatch . ':' . (len(matchRet) - 1) . ']'
    endif
    call extend(ret, predictRet)
    call extend(ret, matchRet)

    " remove duplicate
    let i = 0
    let iEnd = len(ret)
    let exists = {}
    while i < iEnd
        let item = ret[i]
        let hash = item['len'] . item['key'] . item['word']
        if exists('exists[hash]')
            call remove(ret, i)
            let iEnd -= 1
            let i -= 1
        else
            let exists[hash] = 1
        endif
        let i += 1
    endwhile

    return ret
endfunction

function! s:sentence(match, dbMap, key, keyLen)
    let i = a:keyLen
    while i > 0
        let sub = strpart(a:key, 0, i)
        if exists('a:dbMap[sub]')
            let word = a:dbMap[sub][0]
            let a:match['len'] += i
            let a:match['key'] .= sub
            let a:match['word'] .= word['word']
            call add(a:match['sentenceList'], extend({'key' : sub}, word))
            return s:sentence(a:match, a:dbMap, strpart(a:key, i), a:keyLen - i) + 1
        endif
        let i -= 1
    endwhile
    return 0
endfunction

function! s:predict(ret, retInitLen, dbMap, prefixLen, predictPrefix, predictDb)
    for c in keys(a:predictDb)
        if c != g:ZFVimIM_dbHasWord
            call s:predict(a:ret, a:retInitLen, a:dbMap, a:prefixLen, a:predictPrefix . c, a:predictDb[c])
            if g:ZFVimIM_predictLimit > 0 && len(a:ret) - a:retInitLen >= g:ZFVimIM_predictLimit
                return
            endif
        endif

        if c == g:ZFVimIM_dbHasWord
            for w in a:dbMap[a:predictPrefix]
                call add(a:ret, {
                            \   'len' : a:prefixLen,
                            \   'key' : a:predictPrefix,
                            \   'word' : w['word'],
                            \   'type' : 'predict',
                            \ })
                if g:ZFVimIM_predictLimit > 0 && len(a:ret) - a:retInitLen >= g:ZFVimIM_predictLimit
                    return
                endif
            endfor
            continue
        endif
    endfor
endfunction

" ============================================================
function! s:dbLoad(db, dbFile, ...)
    if !exists("a:db['dbMap']")
        let a:db['dbMap'] = {}
    endif
    if !exists("a:db['dbKeyMap']")
        let a:db['dbKeyMap'] = {}
    endif
    if !exists("a:db['dbEdit']")
        let a:db['dbEdit'] = []
    endif

    let lines = readfile(a:dbFile)
    if empty(lines)
        return
    endif
    for line in lines
        let separatorPos = match(line, ' ')
        if separatorPos <= 0
            continue
        endif
        if match(line, '\\ ') >= 0
            let wordList = split(substitute(line, '\\ ', '_ZFVimIM_space_', 'g'))
            if !empty(wordList)
                call remove(wordList, 0)
            endif

            let list = []
            for word in wordList
                call add(list, {
                            \   'word' : substitute(word, '_ZFVimIM_space_', ' ', 'g'),
                            \   'count' : 0,
                            \ })
            endfor
        else
            let list = []
            let wordList = split(line)
            if !empty(wordList)
                call remove(wordList, 0)
                for word in wordList
                    call add(list, {
                                \   'word' : word,
                                \   'count' : 0,
                                \ })
                endfor
            endif
        endif
        if !empty(list)
            let key = strpart(line, 0, separatorPos)
            let a:db['dbMap'][key] = list
            call s:dbKeyMapAdd(a:db['dbMap'], a:db['dbKeyMap'], key)
        endif
    endfor

    let dbCountFile = get(a:, 1, '')
    if filereadable(dbCountFile)
        let lines = readfile(dbCountFile)
        let countMap = {}
        for line in lines
            let countList = split(line)
            if len(countList) <= 1
                continue
            endif
            let key = countList[0]
            if !exists("a:db['dbMap'][key]")
                continue
            endif
            let wordList = a:db['dbMap'][key]
            let wordListLen = len(wordList)
            for i in range(len(countList) - 1)
                if i >= wordListLen
                    break
                endif
                let wordList[i]['count'] = countList[i + 1]
            endfor
            call ZFVimIM_wordListUpdate(wordList)
        endfor
    endif
endfunction

function! s:dbSave(db, dbFile, ...)
    let dbCountFile = get(a:, 1, '')
    if !filewritable(dbCountFile)
        let dbCountFile = ''
    endif

    if empty(dbCountFile)
        let dbMap = a:db['dbMap']
        let keys = sort(keys(dbMap))
        let lines = []
        for key in keys
            let line = key
            for word in dbMap[key]
                let line .= ' '
                let line .= substitute(word['word'], ' ', '\\ ', 'g')
            endfor
            call add(lines, line)
        endfor
        call writefile(lines, a:dbFile)
    else
        let dbMap = a:db['dbMap']
        let keys = sort(keys(dbMap))
        let lines = []
        let countLines = []
        for key in keys
            let line = key
            let countLine = key
            for word in dbMap[key]
                let line .= ' '
                let line .= substitute(word['word'], ' ', '\\ ', 'g')

                let countLine .= ' '
                let countLine .= word['count']
            endfor
            call add(lines, line)
            call add(countLines, countLine)
        endfor
        call writefile(lines, a:dbFile)
        call writefile(countLines, dbCountFile)
    endif
endfunction

function! s:dbClear(db)
    let a:db['dbMap'] = {}
    let a:db['dbKeyMap'] = {}
    let a:db['dbEdit'] = []
endfunction

" ============================================================
function! s:dbEditWildKey(action, word, key)
    if g:ZFVimIM_dbIndex >= len(g:ZFVimIM_db)
        return
    endif
    if !empty(a:key)
        call s:dbEdit(a:action, a:word, a:key)
        return
    endif
    if empty(a:word)
        return
    endif

    let keyToApply = []
    let db = g:ZFVimIM_db[g:ZFVimIM_dbIndex]
    let dbMap = db['dbMap']
    for k in keys(dbMap)
        if ZFVimIM_wordIndex(dbMap[k], a:word) >= 0
            call add(keyToApply, k)
        endif
    endfor

    for k in keyToApply
        call s:dbEdit(a:action, a:word, k)
    endfor
endfunction

function! s:dbEdit(action, word, key)
    if empty(a:key) || empty(a:word) || g:ZFVimIM_dbIndex >= len(g:ZFVimIM_db)
        return
    endif
    let db = g:ZFVimIM_db[g:ZFVimIM_dbIndex]
    if !exists("db['dbEdit']")
        let db['dbEdit'] = []
    endif
    call add(db['dbEdit'], {
                \   'action' : a:action,
                \   'key' : a:key,
                \   'word' : a:word,
                \ })
    call s:dbEditApply(db, db['dbEdit'])
    doautocmd User ZFVimIM_event_OnUpdateDb
endfunction

function! s:dbEditApply(db, dbEdit)
    call s:dbEditMap(a:db['dbMap'], a:dbEdit)
    call s:dbEditKeyMap(a:db['dbMap'], a:db['dbKeyMap'], a:dbEdit)
endfunction

function! s:dbEditMap(dbMap, dbEdit)
    let dbMap = a:dbMap
    let dbEdit = a:dbEdit
    for e in dbEdit
        let key = e['key']
        let word = e['word']
        if e['action'] == 'add'
            if exists('dbMap[key]')
                let wordList = dbMap[key]
                let index = ZFVimIM_wordIndex(wordList, word)
                if index >= 0
                    let wordList[index]['count'] += 1
                else
                    call add(wordList, {
                                \   'word' : word,
                                \   'count' : 1,
                                \ })
                endif
            else
                let dbMap[key] = [{
                            \   'word' : word,
                            \   'count' : 1,
                            \ }]
            endif
            call ZFVimIM_wordListUpdate(dbMap[key])
        elseif e['action'] == 'remove'
            if !exists('dbMap[key]')
                continue
            endif
            let wordList = dbMap[key]
            let index = ZFVimIM_wordIndex(wordList, word)
            if index < 0
                continue
            endif
            call remove(wordList, index)
            if empty(wordList)
                call remove(dbMap, key)
            endif
        elseif e['action'] == 'reorder'
            if !exists('dbMap[key]')
                continue
            endif
            let wordList = dbMap[key]
            let index = ZFVimIM_wordIndex(wordList, word)
            if index < 0
                continue
            endif
            let wordList[index]['count'] = 0
            let sum = 0
            for wordData in wordList
                let sum += wordData['count']
            endfor
            let wordList[index]['count'] = float2nr(wordList[index]['count'] / 2)
            call ZFVimIM_wordListUpdate(dbMap[key])
        endif
    endfor
endfunction

function! s:dbEditKeyMap(dbMap, dbKeyMap, dbEdit)
    for e in a:dbEdit
        let key = e['key']
        if e['action'] == 'add'
            call s:dbKeyMapAdd(a:dbMap, a:dbKeyMap, key)
        elseif e['action'] == 'remove'
            call s:dbKeyMapRemove(a:dbMap, a:dbKeyMap, key)
        elseif e['action'] == 'reorder'
            " nothing to do
        endif
    endfor
endfunction

function! s:dbKeyMapAdd(dbMap, dbKeyMap, key)
    if g:ZFVimIM_predictLimit == 0
        return
    endif

    let dbKeyMap = a:dbKeyMap
    for i in range(len(a:key))
        let c = a:key[i]
        if exists('dbKeyMap[c]')
            let dbKeyMap = dbKeyMap[c]
        else
            let dbKeyMap[c] = {}
            let dbKeyMap = dbKeyMap[c]
        endif
    endfor
    let dbKeyMap[g:ZFVimIM_dbHasWord] = ''
endfunction

function! s:dbKeyMapRemove(dbMap, dbKeyMap, key)
    if g:ZFVimIM_predictLimit == 0
        return
    endif

    let dbKeyMapStack = []
    let charStack = []
    let dbKeyMap = a:dbKeyMap
    let i = 0
    let keyLen = len(a:key)
    while i < keyLen
        let c = a:key[i]
        call add(dbKeyMapStack, dbKeyMap)
        call add(charStack, c)
        if !exists('dbKeyMap[c]')
            break
        endif
        let dbKeyMap = dbKeyMap[c]
        let i += 1
    endwhile
    if i == keyLen
        if !exists('a:dbMap[a:key]')
            if exists('dbKeyMap[g:ZFVimIM_dbHasWord]')
                unlet dbKeyMap[g:ZFVimIM_dbHasWord]
            endif
        endif
    endif
    let i = len(dbKeyMapStack) - 1
    while i != 0
        if !empty("dbKeyMapStack[i]")
            break
        endif
        unlet dbKeyMapStack[i-1][charStack[i-1]]
        let i -= 1
    endwhile
endfunction

" ============================================================
if 0 " test db
    let g:ZFVimIM_db = [{
                \   'name' : 'test',
                \   'dbMap' : {
                \     'a' : [
                \       {
                \         'word' : '啊',
                \         'count' : 123,
                \       },
                \       {
                \         'word' : '阿',
                \         'count' : 0,
                \       },
                \     ],
                \     'ai' : [
                \       {
                \         'word' : '爱',
                \         'count' : 123,
                \       },
                \       {
                \         'word' : '哀',
                \         'count' : 0,
                \       },
                \     ],
                \     'ceshi' : [
                \       {
                \         'word' : '测试',
                \         'count' : 123,
                \       },
                \     ],
                \   },
                \   'dbKeyMap' : {
                \     'a' : {
                \       g:ZFVimIM_dbHasWord : '',
                \       'i' : {
                \         'g:ZFVimIM_dbHasWord' : '',
                \       },
                \     },
                \     'c' : {
                \       'e' : {
                \         's' : {
                \           'h' : {
                \             'i' : {
                \               g:ZFVimIM_dbHasWord : '',
                \             },
                \           },
                \         },
                \       },
                \     },
                \   },
                \   'dbEdit' : [
                \   ],
                \ }]
endif

