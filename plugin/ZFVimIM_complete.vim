
" params:
"   key : the input key, e.g. `ceshi`
"   option: {
"     'sentence' : '0/1',
"     'crossDb' : 'maxNum, default to g:ZFVimIM_crossDbLimit',
"     'predict' : 'maxNum, default to g:ZFVimIM_predictLimit',
"     'match' : '', // > 0 : limit to this num, allow sub match
"                   // = 0 : disable match
"                   // < 0 : limit to (0-match) num, disallow sub match
"                   // default to 2000
"     'db' : {
"       // db object in g:ZFVimIM_db
"       // when specified, use the specified db, otherwise use current db
"     },
"   }
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
function! ZFVimIM_completeDefault(key, ...)
    let option = get(a:, 1, {})
    let db = get(option, 'db', {})
    if empty(db) && g:ZFVimIM_dbIndex < len(g:ZFVimIM_db)
        let db = g:ZFVimIM_db[g:ZFVimIM_dbIndex]
    endif
    if empty(a:key) || empty(db)
        return []
    endif

    if !exists("option['dbSearchCache']")
        let option['dbSearchCache'] = {}
    endif

    if ZFJobFuncCallable(get(db, 'dbCallback', ''))
        let option = copy(option)
        let option['db'] = db
        call ZFVimIM_DEBUG_profileStart('dbCallback')
        let ret = ZFJobFuncCall(db['dbCallback'], [a:key, option])
        call ZFVimIM_DEBUG_profileStop()
        return ret
    endif

    let data = {
                \   'sentence' : [],
                \   'crossDb' : [],
                \   'predict' : [],
                \   'match' : [],
                \ }

    call s:complete_sentence(data['sentence'], a:key, option, db)
    call s:complete_crossDb(data['crossDb'], a:key, option, db)
    call s:complete_predict(data['predict'], a:key, option, db)
    call s:complete_match(data['match'], a:key, option, db)

    return s:mergeResult(data, a:key, option, db)
endfunction


function! s:complete_sentence(ret, key, option, db)
    if !get(a:option, 'sentence', 1)
        return
    endif

    let sentence = {
                \   'dbId' : a:db['dbId'],
                \   'len' : 0,
                \   'key' : '',
                \   'word' : '',
                \   'type' : 'sentence',
                \   'sentenceList' : [],
                \ }
    let keyLen = len(a:key)
    let iL = 0
    let iR = keyLen
    while iL < keyLen && iR > iL
        let subKey = strpart(a:key, iL, iR - iL)
        let index = ZFVimIM_dbSearch(a:db, subKey[0],
                    \ '^' . subKey,
                    \ 0)
        if index < 0
            let iR -= 1
            continue
        endif
        let index = ZFVimIM_dbSearch(a:db, subKey[0],
                    \ '^' . subKey . g:ZFVimIM_KEY_S_MAIN,
                    \ 0)
        if index < 0
            let iR -= 1
            continue
        endif

        let dbItem = ZFVimIM_dbItemDecode(a:db['dbMap'][subKey[0]][index])
        if empty(dbItem['wordList'])
            let iR -= 1
            continue
        endif
        let sentence['len'] += len(subKey)
        let sentence['key'] .= subKey
        let sentence['word'] .= dbItem['wordList'][0]
        call add(sentence['sentenceList'], {
                    \   'key' : subKey,
                    \   'word' : dbItem['wordList'][0],
                    \ })
        let iL = iR
        let iR = keyLen
    endwhile

    if len(sentence['sentenceList']) > 1
        call add(a:ret, sentence)
    endif
endfunction


function! s:complete_crossDb(ret, key, option, db)
    let crossDbLimit = get(a:option, 'crossDb', g:ZFVimIM_crossDbLimit)
    if crossDbLimit <= 0
        return
    endif

    let crossDbRetList = []
    for crossDbTmp in g:ZFVimIM_db
        if crossDbTmp['dbId'] == a:db['dbId']
            continue
        endif
        let otherDbRet = ZFVimIM_complete(a:key, {
                    \   'sentence' : 0,
                    \   'crossDb' : 0,
                    \   'predict' : 0,
                    \   'match' : (g:ZFVimIM_crossDbAllowSubMatch ? crossDbLimit : (0 - crossDbLimit)),
                    \   'db' : crossDbTmp,
                    \ })
        if !empty(otherDbRet)
            call add(crossDbRetList, otherDbRet)
        endif
    endfor
    if empty(crossDbRetList)
        return
    endif

    let crossDbIndex = 0
    while !empty(crossDbRetList) && len(a:ret) < crossDbLimit
        if empty(crossDbRetList[crossDbIndex])
            call remove(crossDbRetList, crossDbIndex)
            let crossDbIndex = crossDbIndex % len(crossDbRetList)
            continue
        endif
        call add(a:ret, crossDbRetList[crossDbIndex][0])
        call remove(crossDbRetList[crossDbIndex], 0)
        let crossDbIndex = (crossDbIndex + 1) % len(crossDbRetList)
    endwhile
endfunction

function! s:complete_predict(ret, key, option, db)
    let predictLimit = get(a:option, 'predict', g:ZFVimIM_predictLimit)
    if predictLimit <= 0
        return
    endif

    let p = len(a:key)
    while p > 0
        let subKey = strpart(a:key, 0, p)
        let subMatchIndex = ZFVimIM_dbSearch(a:db, a:key[0],
                    \ '^' . subKey,
                    \ 0)
        if subMatchIndex < 0
            let p -= 1
            continue
        endif
        let dbItem = ZFVimIM_dbItemDecode(a:db['dbMap'][a:key[0]][subMatchIndex])
        if dbItem['key'] == subKey
            " as for predict, we don't care for exact match
            break
        endi

        " found things to predict
        let wordIndex = 0
        while len(a:ret) < predictLimit
            call add(a:ret, {
                        \   'dbId' : a:db['dbId'],
                        \   'len' : p,
                        \   'key' : dbItem['key'],
                        \   'word' : dbItem['wordList'][wordIndex],
                        \   'type' : 'predict',
                        \ })
            let wordIndex += 1
            if wordIndex < len(dbItem['wordList'])
                continue
            endif

            " find next predict
            while 1
                let subMatchIndex = ZFVimIM_dbSearch(a:db, a:key[0],
                            \ '^' . subKey,
                            \ subMatchIndex + 1)
                if subMatchIndex < 0
                    break
                endif
                let dbItem = ZFVimIM_dbItemDecode(a:db['dbMap'][a:key[0]][subMatchIndex])
                if dbItem['key'] != subKey
                    let wordIndex = 0
                    break
                endi
            endwhile
            if subMatchIndex < 0
                break
            endif
        endwhile

        break
    endwhile
endfunction

function! s:complete_match(ret, key, option, db)
    let matchLimit = get(a:option, 'match', 2000)
    if matchLimit < 0
        call s:complete_match_exact(a:ret, a:key, a:option, a:db, 0 - matchLimit)
    elseif matchLimit > 0
        call s:complete_match_allowSubMatch(a:ret, a:key, a:option, a:db, matchLimit)
    endif
endfunction

function! s:complete_match_exact(ret, key, option, db, matchLimit)
    let index = ZFVimIM_dbSearch(a:db, a:key[0],
                \ '^' . a:key,
                \ 0)
    if index < 0
        return
    endif
    let index = ZFVimIM_dbSearch(a:db, a:key[0],
                \ '^' . a:key . g:ZFVimIM_KEY_S_MAIN,
                \ 0)
    if index < 0
        return
    endif

    " found match
    let matchLimit = a:matchLimit
    let keyLen = len(a:key)
    while index >= 0
        let dbItem = ZFVimIM_dbItemDecode(a:db['dbMap'][a:key[0]][index])
        if len(dbItem['wordList']) < matchLimit
            let numToAdd = len(dbItem['wordList'])
        else
            let numToAdd = matchLimit
        endif
        let matchLimit -= numToAdd
        let wordIndex = 0
        while wordIndex < numToAdd
            call add(a:ret, {
                        \   'dbId' : a:db['dbId'],
                        \   'len' : keyLen,
                        \   'key' : a:key,
                        \   'word' : dbItem['wordList'][wordIndex],
                        \   'type' : 'match',
                        \ })
            let wordIndex += 1
        endwhile
        if matchLimit <= 0
            break
        endif
        let index = ZFVimIM_dbSearch(a:db, a:key[0],
                    \ '^' . a:key . g:ZFVimIM_KEY_S_MAIN,
                    \ index + 1)
    endwhile
endfunction

function! s:complete_match_allowSubMatch(ret, key, option, db, matchLimit)
    let matchLimit = a:matchLimit
    let p = len(a:key)
    while p > 0 && matchLimit > 0
        let subKey = strpart(a:key, 0, p)
        let index = ZFVimIM_dbSearch(a:db, a:key[0],
                    \ '^' . subKey,
                    \ 0)
        if index < 0
            let p -= 1
            continue
        endif
        let index = ZFVimIM_dbSearch(a:db, a:key[0],
                    \ '^' . subKey . g:ZFVimIM_KEY_S_MAIN,
                    \ 0)
        if index < 0
            let p -= 1
            continue
        endif

        " found match
        let dbItem = ZFVimIM_dbItemDecode(a:db['dbMap'][a:key[0]][index])
        if len(dbItem['wordList']) < matchLimit
            let numToAdd = len(dbItem['wordList'])
        else
            let numToAdd = matchLimit
        endif
        let matchLimit -= numToAdd
        let wordIndex = 0
        while wordIndex < numToAdd
            call add(a:ret, {
                        \   'dbId' : a:db['dbId'],
                        \   'len' : p,
                        \   'key' : subKey,
                        \   'word' : dbItem['wordList'][wordIndex],
                        \   'type' : 'match',
                        \ })
            let wordIndex += 1
        endwhile

        let p -= 1
    endwhile
endfunction

" data: {
"   'sentence' : [],
"   'crossDb' : [],
"   'predict' : [],
"   'match' : [],
" }
" return final result list
function! s:mergeResult(data, key, option, db)
    let ret = []
    let sentenceRet = a:data['sentence']
    let crossDbRet = a:data['crossDb']
    let predictRet = a:data['predict']
    let matchRet = a:data['match']

    " limit crossDb if has predict or match
    if len(sentenceRet) + len(predictRet) + len(matchRet) >= 5 && len(crossDbRet) > g:ZFVimIM_crossDbLimitWhenMatch
        call remove(crossDbRet, g:ZFVimIM_crossDbLimitWhenMatch, len(crossDbRet) - 1)
    endif

    " limit predict if has match
    if len(sentenceRet) + len(matchRet) >= 5 && len(predictRet) > g:ZFVimIM_predictLimitWhenMatch
        call remove(predictRet, g:ZFVimIM_predictLimitWhenMatch, len(predictRet) - 1)
    endif

    " sentence > predict > match
    call extend(ret, sentenceRet)
    call extend(ret, predictRet)
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
    if g:ZFVimIM_crossDbPos >= len(ret)
        for item in crossDbRet
            let hash = item['key'] . item['word']
            if !exists('exists[hash]')
                let exists[hash] = 1
                call add(ret, item)
            endif
        endfor
    else
        for item in crossDbRet
            let hash = item['key'] . item['word']
            if !exists('exists[hash]')
                let exists[hash] = 1
                call insert(ret, item, g:ZFVimIM_crossDbPos)
            endif
        endfor
    endif

    return ret
endfunction

