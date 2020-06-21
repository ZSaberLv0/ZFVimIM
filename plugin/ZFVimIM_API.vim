
" ============================================================
if !exists('g:ZFVimIM_predictLimitWhenMatch')
    let g:ZFVimIM_predictLimitWhenMatch = 5
endif
if !exists('g:ZFVimIM_predictLimit')
    let g:ZFVimIM_predictLimit = 10
endif

if !exists('g:ZFVimIM_crossDbLimitWhenMatch')
    let g:ZFVimIM_crossDbLimitWhenMatch = 2
endif
if !exists('g:ZFVimIM_crossDbLimit')
    let g:ZFVimIM_crossDbLimit = 4
endif
if !exists('g:ZFVimIM_crossDbMatchOnly')
    let g:ZFVimIM_crossDbMatchOnly = 1
endif
if !exists('g:ZFVimIM_crossDbPos')
    let g:ZFVimIM_crossDbPos = 5
endif

if !exists('g:ZFVimIM_cachePath')
    let g:ZFVimIM_cachePath = get(g:, 'zf_vim_cache_path', $HOME . '/.vim_cache') . '/ZFVimIM'
endif

function! ZFVimIM_cachePath()
    if !isdirectory(g:ZFVimIM_cachePath)
        call mkdir(g:ZFVimIM_cachePath, 'p')
    endif
    return g:ZFVimIM_cachePath
endfunction

" db : [
"   { // name,dbMap,dbKeyMap,dbEdit
"     'dbId' : 'auto generated id',
"     'name' : 'name of the db, ZFVimIM by default',
"     'priority' : 'priority of the db, smaller value has higher priority, 100 by default',
"     'dbMap' : {
"       // use plain string to save memory
"       'a' : '啊\n阿\r123\n0',
"       'ai' : '爱\n哀\r123\n0',
"       'ceshi' : '测试\r123',
"     },
"     'dbKeyMap' : {
"       'a' : {
"         g:ZFVimIM_KEY_HAS_WORD : '', <= an empty item to mark this node has word
"         'i' : {
"           g:ZFVimIM_KEY_HAS_WORD : '',
"         },
"       },
"       'c' : {
"         'e' : {
"           's' : {
"             'h' : {
"               'i' : {
"                 g:ZFVimIM_KEY_HAS_WORD : '',
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
"     'implData' : {
"       // extra data for impl
"     },
"   },
"   ...
" ]
if !exists('g:ZFVimIM_db')
    let g:ZFVimIM_db = []
endif
if !exists('g:ZFVimIM_dbIndex')
    let g:ZFVimIM_dbIndex = 0
endif

let g:ZFVimIM_KEY_HAS_WORD = '@@'

" ============================================================
augroup ZFVimIM_event_OnUpdateDb_augroup
    autocmd!
    autocmd User ZFVimIM_event_OnUpdateDb silent! echo ''
augroup END

" ============================================================
function! ZFVimIM_dbInit(option)
    let db = extend({
                \   'dbId' : -1,
                \   'name' : 'ZFVimIM',
                \   'priority' : -1,
                \   'dbMap' : {},
                \   'dbKeyMap' : {},
                \   'dbEdit' : [],
                \   'implData' : {},
                \ }, a:option)
    if db['priority'] < 0
        let db['priority'] = 100
    endif

    let s:dbId = get(s:, 'dbId', 0) + 1
    while ZFVimIM_dbIndexForId(s:dbId) >= 0
        let s:dbId += 1
        if s:dbId <= 0
            let s:dbId = 1
        endif
    endwhile
    let db['dbId'] = s:dbId

    let index = len(g:ZFVimIM_db) - 1
    while index >= 0 && db['priority'] < g:ZFVimIM_db[index]['priority']
        let index -= 1
    endwhile
    if index < 0
        let index = 0
    endif
    call insert(g:ZFVimIM_db, db, index)

    return db
endfunction

function! ZFVimIM_dbIndexForId(dbId)
    for dbIndex in range(len(g:ZFVimIM_db))
        if g:ZFVimIM_db[dbIndex]['dbId'] == a:dbId
            return dbIndex
        endif
    endfor
    return -1
endfunction
function! ZFVimIM_dbForId(dbId)
    for dbIndex in range(len(g:ZFVimIM_db))
        if g:ZFVimIM_db[dbIndex]['dbId'] == a:dbId
            return g:ZFVimIM_db[dbIndex]
        endif
    endfor
    return {}
endfunction

function! ZFVimIM_dbLoad(db, dbFile, ...)
    call ZFVimIM_DEBUG_profileStart('dbLoad')
    call s:dbLoad(a:db, a:dbFile, get(a:, 1, ''))
    call ZFVimIM_DEBUG_profileStop()
endfunction
function! ZFVimIM_dbSave(db, dbFile, ...)
    call ZFVimIM_DEBUG_profileStart('dbSave')
    call s:dbSave(a:db, a:dbFile, get(a:, 1, ''))
    call ZFVimIM_DEBUG_profileStop()
endfunction
function! ZFVimIM_dbClear(db)
    call s:dbClear(a:db)
endfunction

function! ZFVimIM_dbEditApply(db, dbEdit)
    call ZFVimIM_DEBUG_profileStart('dbEditApply')
    call s:dbEditApply(a:db, a:dbEdit)
    call ZFVimIM_DEBUG_profileStop()
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

function! s:dbMapItemReorderFunc(item1, item2)
    return (a:item2['count'] - a:item1['count'])
endfunction
function! ZFVimIM_dbMapItemReorder(dbMapItem)
    call ZFVimIM_DEBUG_profileStart('ItemReorder')
    let tmp = []
    let i = 0
    let iEnd = len(a:dbMapItem['wordList'])
    while i < iEnd
        call add(tmp, {
                    \   'word' : a:dbMapItem['wordList'][i],
                    \   'count' : a:dbMapItem['countList'][i],
                    \ })
        let i += 1
    endwhile
    call sort(tmp, function('s:dbMapItemReorderFunc'))
    let a:dbMapItem['wordList'] = []
    let a:dbMapItem['countList'] = []
    for item in tmp
        call add(a:dbMapItem['wordList'], item['word'])
        call add(a:dbMapItem['countList'], item['count'])
    endfor
    call ZFVimIM_DEBUG_profileStop()
endfunction

" encoded:
"   '啊\n阿\r123\n0'
" decoded:
"   {
"     'wordList' : [],
"     'countList' : [],
"   }
function! ZFVimIM_dbMapItemDecode(dbMapItem)
    let split = split(a:dbMapItem, "\r")
    let wordList = split(split[0], "\n")
    let countList = []
    for cnt in split(get(split, 1, ''), "\n")
        call add(countList, str2nr(cnt))
    endfor
    while len(countList) < len(wordList)
        call add(countList, 0)
    endwhile
    return {
                \   'wordList' : wordList,
                \   'countList' : countList,
                \ }
endfunction
function! ZFVimIM_dbMapItemEncode(dbMapItem)
    let countText = ''
    for cnt in a:dbMapItem['countList']
        if cnt <= 0
            break
        endif
        let countText .= cnt
        let countText .= "\n"
    endfor
    return join(a:dbMapItem['wordList'], "\n") . "\r" . strpart(countText, 0, len(countText) - 1)
endfunction

" option: {
"   'sentence' : '0/1',
"   'crossDb' : 'maxNum, default to g:ZFVimIM_crossDbLimit',
"   'predict' : 'maxNum, default to g:ZFVimIM_predictLimit',
"   'match' : 'maxNum, default to -1',
" }
" return : [
"   {
"     'dbId' : 'match from which db',
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
function! ZFVimIM_complete(key, ...)
    let option = get(a:, 1, {})
    let db = get(a:, 2, {})
    return ZFVimIM_completeDefault(a:key, option, db)
endfunction

" ============================================================
function! ZFVimIM_completeDefault(key, option, db)
    let db = a:db
    if empty(db) && g:ZFVimIM_dbIndex < len(g:ZFVimIM_db)
        let db = g:ZFVimIM_db[g:ZFVimIM_dbIndex]
    endif
    if empty(a:key) || empty(db)
        return []
    endif
    let key = a:key
    let keyLen = len(key)
    let dbMap = db['dbMap']

    " sentence
    let sentenceRet = []
    if get(a:option, 'sentence', 1)
        let sentence = {
                    \   'dbId' : db['dbId'],
                    \   'len' : 0,
                    \   'key' : '',
                    \   'word' : '',
                    \   'type' : 'sentence',
                    \   'sentenceList' : [],
                    \ }
        if s:sentence(sentence, dbMap, key, keyLen) > 1
            call add(sentenceRet, sentence)
        endif
    endif

    " crossDb
    let crossDbRet = []
    if get(a:option, 'crossDb', g:ZFVimIM_crossDbLimit) > 0
        for crossDbTmp in g:ZFVimIM_db
            if crossDbTmp['dbId'] != db['dbId']
                call extend(crossDbRet, ZFVimIM_complete(key, {
                            \   'sentence' : 0,
                            \   'crossDb' : 0,
                            \   'predict' : 0,
                            \   'match' : get(a:option, 'crossDb', g:ZFVimIM_crossDbLimit),
                            \ }, crossDbTmp))
            endif
        endfor
        if g:ZFVimIM_crossDbMatchOnly && !empty(crossDbRet)
            let crossDbRetIndex = len(crossDbRet) - 1
            while crossDbRetIndex >= 0
                if crossDbRet[crossDbRetIndex]['key'] != key
                    call remove(crossDbRet, crossDbRetIndex)
                endif
                let crossDbRetIndex -= 1
            endwhile
        endif
    endif

    " predict
    let predictRet = []
    if get(a:option, 'predict', g:ZFVimIM_predictLimit) > 0
        let predictPrefix = ''
        let predictDb = db['dbKeyMap']
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
            call s:predict(predictRet, len(predictRet), db, len(predictPrefix), predictPrefix, predictDb, a:option)
        endif
    endif

    " exact match
    let matchRet = []
    let match = get(a:option, 'match', -1)
    if match != 0
        if match < 0
            let match = 9999
        endif
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
            for w in ZFVimIM_dbMapItemDecode(dbMap[k])['wordList']
                call add(matchRet, {
                            \   'dbId' : db['dbId'],
                            \   'len' : len(k),
                            \   'key' : k,
                            \   'word' : w,
                            \   'type' : 'match',
                            \ })
                if len(matchRet) >= match
                    break
                endif
            endfor
            let i -= 1
            if len(matchRet) >= match
                break
            endif
        endwhile
    endif

    " limit crossDb if has predict or match
    if len(sentenceRet) + len(predictRet) + len(matchRet) >= 5 && len(crossDbRet) > g:ZFVimIM_crossDbLimitWhenMatch
        call remove(crossDbRet, g:ZFVimIM_crossDbLimitWhenMatch, len(crossDbRet) - 1)
    endif

    " limit predict if has match
    if len(sentenceRet) + len(matchRet) >= 5 && len(predictRet) > g:ZFVimIM_predictLimitWhenMatch
        call remove(predictRet, g:ZFVimIM_predictLimitWhenMatch, len(predictRet) - 1)
    endif

    " result
    let ret = []
    " sentence always first
    call extend(ret, sentenceRet)
    " predict
    call extend(ret, predictRet)
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
    call extend(ret, matchRet)

    " remove duplicate
    let i = 0
    let iEnd = len(ret)
    let exists = {}
    while i < iEnd
        let item = ret[i]
        let hash = item['key'] . item['word']
        if exists('exists[hash]')
            call remove(ret, i)
            let iEnd -= 1
            let i -= 1
        else
            let exists[hash] = 1
        endif
        let i += 1
    endwhile

    " crossDb should be placed at lower order,
    " also, we need duplicate check
    for item in crossDbRet
        let hash = item['key'] . item['word']
        if !exists('exists[hash]')
            let exists[hash] = 1
            if g:ZFVimIM_crossDbPos >= len(ret)
                call add(ret, item)
            else
                call insert(ret, item, g:ZFVimIM_crossDbPos)
            endif
        endif
    endfor

    return ret
endfunction

function! s:sentence(match, dbMap, key, keyLen)
    let i = a:keyLen
    while i > 0
        let sub = strpart(a:key, 0, i)
        if exists('a:dbMap[sub]')
            let word = ZFVimIM_dbMapItemDecode(a:dbMap[sub])['wordList'][0]
            let a:match['len'] += i
            let a:match['key'] .= sub
            let a:match['word'] .= word
            call add(a:match['sentenceList'], {
                        \   'key' : sub,
                        \   'word' : word,
                        \ })
            return s:sentence(a:match, a:dbMap, strpart(a:key, i), a:keyLen - i) + 1
        endif
        let i -= 1
    endwhile
    return 0
endfunction

function! s:predict(ret, retInitLen, db, prefixLen, predictPrefix, predictDb, option)
    if exists('a:predictDb[g:ZFVimIM_KEY_HAS_WORD]')
        for word in ZFVimIM_dbMapItemDecode(a:db['dbMap'][a:predictPrefix])['wordList']
            call add(a:ret, {
                        \   'dbId' : a:db['dbId'],
                        \   'len' : a:prefixLen,
                        \   'key' : a:predictPrefix,
                        \   'word' : word,
                        \   'type' : a:prefixLen == len(a:predictPrefix) ? 'match' : 'predict',
                        \ })
            if len(a:ret) - a:retInitLen >= get(a:option, 'predict', g:ZFVimIM_predictLimit)
                return
            endif
        endfor
    endif

    for c in keys(a:predictDb)
        if c != g:ZFVimIM_KEY_HAS_WORD
            call s:predict(a:ret, a:retInitLen, a:db, a:prefixLen, a:predictPrefix . c, a:predictDb[c], a:option)
            if len(a:ret) - a:retInitLen >= get(a:option, 'predict', g:ZFVimIM_predictLimit)
                return
            endif
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

    call ZFVimIM_DEBUG_profileStart('dbLoadFile')
    let lines = readfile(a:dbFile)
    call ZFVimIM_DEBUG_profileStop()
    if empty(lines)
        return
    endif
    for line in lines
        if match(line, '\\ ') >= 0
            let wordListTmp = split(substitute(line, '\\ ', '_ZFVimIM_space_', 'g'))
            if !empty(wordListTmp)
                let key = remove(wordListTmp, 0)
            endif

            let wordList = []
            for word in wordListTmp
                call add(wordList, substitute(word, '_ZFVimIM_space_', ' ', 'g'))
            endfor
        else
            let wordList = split(line)
            if !empty(wordList)
                let key = remove(wordList, 0)
            endif
        endif
        if !empty(wordList)
            if exists("a:db['dbMap'][key]")
                let dbMapItem = ZFVimIM_dbMapItemDecode(a:db['dbMap'][key])
                call extend(dbMapItem['wordList'], wordList)
            else
                let dbMapItem = {
                            \   'wordList' : wordList,
                            \   'countList' : [],
                            \ }
            endif
            for i in range(len(wordList))
                call add(dbMapItem['countList'], 0)
            endfor
            let a:db['dbMap'][key] = ZFVimIM_dbMapItemEncode(dbMapItem)
            call s:dbKeyMapAdd(a:db['dbMap'], a:db['dbKeyMap'], key)
        endif
    endfor

    let dbCountFile = get(a:, 1, '')
    if filereadable(dbCountFile)
        call ZFVimIM_DEBUG_profileStart('dbLoadCountFile')
        let lines = readfile(dbCountFile)
        call ZFVimIM_DEBUG_profileStop()
        for line in lines
            let countTextList = split(line)
            if len(countTextList) <= 1
                continue
            endif
            let key = countTextList[0]
            if !exists("a:db['dbMap'][key]")
                continue
            endif
            let dbMapItem = ZFVimIM_dbMapItemDecode(a:db['dbMap'][key])
            let wordListLen = len(dbMapItem['wordList'])
            for i in range(len(countTextList) - 1)
                if i >= wordListLen
                    break
                endif
                let dbMapItem['countList'][i] = str2nr(countTextList[i + 1])
            endfor
            call ZFVimIM_dbMapItemReorder(dbMapItem)
            let a:db['dbMap'][key] = ZFVimIM_dbMapItemEncode(dbMapItem)
        endfor
    endif
endfunction

function! s:dbSave(db, dbFile, ...)
    let dbCountFile = get(a:, 1, '')
    if !filewritable(dbCountFile)
        let dbCountFile = ''
    endif

    let dbMap = a:db['dbMap']
    let lines = []
    if empty(dbCountFile)
        for key in sort(keys(dbMap))
            let line = key
            for word in ZFVimIM_dbMapItemDecode(dbMap[key])['wordList']
                let line .= ' '
                let line .= substitute(word, ' ', '\\ ', 'g')
            endfor
            call add(lines, line)
        endfor
        call ZFVimIM_DEBUG_profileStart('dbSaveFile')
        call writefile(lines, a:dbFile)
        call ZFVimIM_DEBUG_profileStop()
    else
        let countLines = []
        for key in sort(keys(dbMap))
            let line = key
            let countLine = key
            let dbMapItem = ZFVimIM_dbMapItemDecode(dbMap[key])
            for i in range(len(dbMapItem['wordList']))
                let line .= ' '
                let line .= substitute(dbMapItem['wordList'][i], ' ', '\\ ', 'g')
                if dbMapItem['countList'][i] > 0
                    let countLine .= ' '
                    let countLine .= dbMapItem['countList'][i]
                endif
            endfor
            call add(lines, line)
            if countLine != key
                call add(countLines, countLine)
            endif
        endfor
        call ZFVimIM_DEBUG_profileStart('dbSaveFile')
        call writefile(lines, a:dbFile)
        call ZFVimIM_DEBUG_profileStop()
        call ZFVimIM_DEBUG_profileStart('dbSaveCountFile')
        call writefile(countLines, dbCountFile)
        call ZFVimIM_DEBUG_profileStop()
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
        if index(ZFVimIM_dbMapItemDecode(dbMap[k])['wordList'], a:word) >= 0
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
                let dbMapItem = ZFVimIM_dbMapItemDecode(dbMap[key])
                let index = index(dbMapItem['wordList'], word)
                if index >= 0
                    let dbMapItem['countList'][index] += 1
                else
                    call add(dbMapItem['wordList'], word)
                    call add(dbMapItem['countList'], 1)
                endif
                call ZFVimIM_dbMapItemReorder(dbMapItem)
                let dbMap[key] = ZFVimIM_dbMapItemEncode(dbMapItem)
            else
                let dbMap[key] = ZFVimIM_dbMapItemEncode({
                            \   'wordList' : [word],
                            \   'countList' : [1],
                            \ })
            endif
        elseif e['action'] == 'remove'
            if !exists('dbMap[key]')
                continue
            endif
            let dbMapItem = ZFVimIM_dbMapItemDecode(dbMap[key])
            let index = index(dbMapItem['wordList'], word)
            if index < 0
                continue
            endif
            call remove(dbMapItem['wordList'], index)
            call remove(dbMapItem['countList'], index)
            if empty(dbMapItem['wordList'])
                call remove(dbMap, key)
            else
                let dbMap[key] = ZFVimIM_dbMapItemEncode(dbMapItem)
            endif
        elseif e['action'] == 'reorder'
            if !exists('dbMap[key]')
                continue
            endif
            let dbMapItem = ZFVimIM_dbMapItemDecode(dbMap[key])
            let index = index(dbMapItem['wordList'], word)
            if index < 0
                continue
            endif
            let dbMapItem['countList'][index] = 0
            let sum = 0
            for cnt in dbMapItem['countList']
                let sum += cnt
            endfor
            let dbMapItem['countList'][index] = float2nr(dbMapItem['countList'][index] / 2)
            call ZFVimIM_dbMapItemReorder(dbMapItem)
            let dbMap[key] = ZFVimIM_dbMapItemEncode(dbMapItem)
        endif
    endfor
endfunction

function! s:dbEditKeyMap(dbMap, dbKeyMap, dbEdit)
    for e in a:dbEdit
        let key = e['key']
        if e['action'] == 'add'
            call ZFVimIM_DEBUG_profileStart('dbKeyMapAdd')
            call s:dbKeyMapAdd(a:dbMap, a:dbKeyMap, key)
            call ZFVimIM_DEBUG_profileStop()
        elseif e['action'] == 'remove'
            call ZFVimIM_DEBUG_profileStart('dbKeyMapRemove')
            call s:dbKeyMapRemove(a:dbMap, a:dbKeyMap, key)
            call ZFVimIM_DEBUG_profileStop()
        elseif e['action'] == 'reorder'
            " nothing to do
        endif
    endfor
endfunction

function! s:dbKeyMapAdd(dbMap, dbKeyMap, key)
    let dbKeyMap = a:dbKeyMap
    for i in range(len(a:key))
        let c = a:key[i]
        if !exists('dbKeyMap[c]')
            let dbKeyMap[c] = {}
        endif
        let dbKeyMap = dbKeyMap[c]
    endfor
    let dbKeyMap[g:ZFVimIM_KEY_HAS_WORD] = ''
endfunction

function! s:dbKeyMapRemove(dbMap, dbKeyMap, key)
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
            if exists('dbKeyMap[g:ZFVimIM_KEY_HAS_WORD]')
                unlet dbKeyMap[g:ZFVimIM_KEY_HAS_WORD]
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
                \     'a' : "啊\n阿\r123\n0",
                \     'ai' : "爱\n哀\r123\n0",
                \     'ceshi' : "测试\r123",
                \   },
                \   'dbKeyMap' : {
                \     'a' : {
                \       g:ZFVimIM_KEY_HAS_WORD : '',
                \       'i' : {
                \         'g:ZFVimIM_KEY_HAS_WORD' : '',
                \       },
                \     },
                \     'c' : {
                \       'e' : {
                \         's' : {
                \           'h' : {
                \             'i' : {
                \               g:ZFVimIM_KEY_HAS_WORD : '',
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

