
if !exists('g:ZFVimIM_DEBUG_profile')
    let g:ZFVimIM_DEBUG_profile = 0
endif
" result store to g:ZFVimIM_DEBUG_profileData:
" {
"   'name' : {
"     'name' : '',
"     'total' : '',
"     'count' : '',
"     'avg' : '',
"     'min' : '',
"     'max' : '',
"   },
" }
function! ZFVimIM_DEBUG_profileStart(name)
    if !g:ZFVimIM_DEBUG_profile
        return
    endif
    if !exists('s:ZFVimIM_DEBUG_profileStack')
        " {
        "   'name' : '',
        "   'start' : 'reltime()',
        " }
        let s:ZFVimIM_DEBUG_profileStack = []
    endif
    call add(s:ZFVimIM_DEBUG_profileStack, {
                \   'name' : a:name,
                \   'start' : reltime(),
                \ })
endfunction
function! ZFVimIM_DEBUG_profileStop()
    if !g:ZFVimIM_DEBUG_profile || !exists('s:ZFVimIM_DEBUG_profileStack') || empty(s:ZFVimIM_DEBUG_profileStack)
        return
    endif
    if !exists('g:ZFVimIM_DEBUG_profileData')
        let g:ZFVimIM_DEBUG_profileData = {}
    endif
    let stack = remove(s:ZFVimIM_DEBUG_profileStack, len(s:ZFVimIM_DEBUG_profileStack) - 1)
    let name = stack['name']
    let cost = float2nr(reltimefloat(reltime(stack['start'], reltime())) * 1000 * 1000)
    let data = get(g:ZFVimIM_DEBUG_profileData, name, {
                \   'name' : name,
                \   'total' : 0,
                \   'count' : 0,
                \   'avg' : 0,
                \   'min' : -1,
                \   'max' : 0,
                \ })
    let g:ZFVimIM_DEBUG_profileData[name] = data
    let data['total'] += cost
    let data['count'] += 1
    let data['avg'] = data['total'] / data['count']
    if data['min'] < 0 || data['min'] > cost
        let data['min'] = cost
    endif
    if data['max'] < cost
        let data['max'] = cost
    endif
endfunction

function! s:ZFVimIM_DEBUG_profileInfo_sort(e0, e1)
    return a:e1['avg'] - a:e0['avg']
endfunction
function! ZFVimIM_DEBUG_profileInfo()
    let list = values(get(g:, 'ZFVimIM_DEBUG_profileData', {}))
    call sort(list, function('s:ZFVimIM_DEBUG_profileInfo_sort'))
    let ret = []
    for item in list
        call add(ret, [item['name']
                    \ , '  avg:' , string(item['avg']) , ' (' , item['total'] , '/' , string(item['count']) , ')'
                    \ , '  max:' , string(item['max'])
                    \ , '  min:' , string(item['min'])
                    \ ])
    endfor
    let ret = s:joinAligned(ret)
    echo join(ret, "\n")
    return ret
endfunction
function! s:joinAligned(list)
    if empty(a:list)
        return []
    endif
    let n = len(a:list[0])
    let nList = []
    for line in a:list
        for i in range(len(line))
            let len = len(line[i])
            if i >= len(nList)
                call add(nList, len)
            elseif len > nList[i]
                let nList[i] = len
            endif
        endfor
    endfor

    let ret = []
    for line in a:list
        let t = ''
        for i in range(len(line))
            let t .= repeat(' ', nList[i] - len(line[i])) . line[i]
        endfor
        call add(ret, t)
    endfor
    return ret
endfunction

