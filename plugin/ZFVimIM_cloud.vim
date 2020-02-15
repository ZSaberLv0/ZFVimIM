
" ============================================================
" cloudOption: {
"   'repoPath' : 'git repo path',
"   'dbFile' : 'db file path relative to repoPath, must start with /',
"   'dbCountFile' : 'optional, db count file path relative to repoPath, must start with /',
"   'gitUserEmail' : 'git user email',
"   'gitUserName' : 'git user name',
"   'gitUserToken' : 'git access token or password',
"   'dbIndex' : 'index of g:ZFVimIM_db'
" }
" * for sync upload, when git user info not supplied,
"   we would ask user to input
" * for async upload, when git user info not supplied,
"   nothing would happen
function! ZFVimIM_cloudRegister(cloudOption, ...)
    call add(g:ZFVimIM_cloudOption, a:cloudOption)
    " default use sync for init, more friendly for first time typing
    if ZFVimIM_cloudAsyncAvailable() && get(a:, 1, 'sync') == 'async'
        call ZFVimIM_initAsync(a:cloudOption)
    else
        call ZFVimIM_initSync(a:cloudOption)
    endif
endfunction
if !exists('g:ZFVimIM_cloudOption')
    let g:ZFVimIM_cloudOption = []
endif


" ============================================================

function! ZFVimIM_download()
    if ZFVimIM_cloudAsyncAvailable()
        call ZFVimIM_downloadAllAsync()
    else
        call ZFVimIM_downloadAllSync()
    endif
endfunction
function! ZFVimIM_upload()
    if ZFVimIM_cloudAsyncAvailable()
        call ZFVimIM_uploadAllAsync()
    else
        call ZFVimIM_uploadAllSync()
    endif
endfunction
command! -nargs=0 IMCloud :call ZFVimIM_upload()

function! ZFVimIM_cloudLog()
    if ZFVimIM_cloudAsyncAvailable()
        let log = g:ZFVimIM_cloudAsync_log
    else
        let log = g:ZFVimIM_cloudSync_log
    endif

    redraw!
    for line in log
        echo line
    endfor
endfunction
command! -nargs=0 IMCloudLog :call ZFVimIM_cloudLog()


function! ZFVimIM_cloud_gitInfoSupplied(cloudOption)
    return 1
                \ && !empty(get(a:cloudOption, 'gitUserEmail', ''))
                \ && !empty(get(a:cloudOption, 'gitUserName', ''))
                \ && !empty(get(a:cloudOption, 'gitUserToken', ''))
endfunction


" ============================================================
if 0
elseif executable('py')
    let s:py = 'py'
elseif executable('python')
    let s:py = 'python'
elseif executable('py3')
    let s:py = 'py3'
elseif executable('python3')
    let s:py = 'python3'
else
    let s:py = ''
endif

function! ZFVimIM_cloud_file(cloudOption, key)
    if empty(get(a:cloudOption, a:key, ''))
        return ''
    else
        return a:cloudOption['repoPath'] . a:cloudOption[a:key]
    endif
endfunction

function! s:realPath(path)
    if has("win32unix") && executable('cygpath')
        return substitute(system('cygpath -w "' . a:path . '"'), '[\r\n]', '', 'g')
    elseif has('win32')
        return substitute(a:path, '/', '\\', 'g')
    else
        return a:path
    endif
endfunction
let s:scriptPath = s:realPath(expand('<sfile>:p:h:h') . '/misc/')

function! ZFVimIM_cloud_dbDownloadCmd(cloudOption)
    if has('unix')
        return 'sh'
                    \ . ' "' . s:scriptPath . 'dbDownload.sh' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
    else
        return '"' . s:scriptPath . 'dbDownload.bat' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
    endif
endfunction
function! ZFVimIM_cloud_dbUploadCmd(cloudOption)
    if has('unix')
        return 'sh'
                    \ . ' "' . s:scriptPath . 'dbUpload.sh' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
    else
        return '"' . s:scriptPath . 'dbUpload.bat' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
    endif
endfunction
function! ZFVimIM_cloud_dbCleanupCmd(cloudOption)
    if has('unix')
        let path = split(globpath(&rtp, '/misc/git_hard_remove_all_history.sh'), '\n')
        if empty(path)
            return ''
        endif
        let path = substitute(path[0], '[\r\n]', '', 'g')
        let path = fnamemodify(fnamemodify(path, ':.'), ':p')
        return 'sh'
                    \ . ' "' . s:scriptPath . 'dbCleanup.sh' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
                    \ . ' "' . s:realPath(path) . '"'
                    \ . ' "' . s:realPath(g:ZFVimIM_cachePath) . '"'
    else
        let path = split(globpath(&rtp, '/misc/git_hard_remove_all_history.bat'), '\n')
        if empty(path)
            return ''
        endif
        let path = substitute(path[0], '[\r\n]', '', 'g')
        let path = fnamemodify(fnamemodify(path, ':.'), ':p')
        return '"' . s:scriptPath . 'dbCleanup.bat' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
                    \ . ' "' . s:realPath(path) . '"'
                    \ . ' "' . s:realPath(g:ZFVimIM_cachePath) . '"'
    endif
endfunction

function! ZFVimIM_cloud_dbLoadCmd(cloudOption, dbJsonFile)
    if empty(s:py)
        return ''
    endif
    return s:py
                \ . ' "' . s:scriptPath . 'dbLoad.py' . '"'
                \ . ' "' . s:realPath(a:dbJsonFile) . '"'
                \ . ' "' . s:realPath(ZFVimIM_cloud_file(a:cloudOption, 'dbFile')) . '"'
                \ . ' "' . s:realPath(ZFVimIM_cloud_file(a:cloudOption, 'dbCountFile')) . '"'
endfunction
function! ZFVimIM_cloud_dbSaveCmd(cloudOption, dbJsonFile)
    if empty(s:py)
        return ''
    endif
    return s:py
                \ . ' "' . s:scriptPath . 'dbSave.py' . '"'
                \ . ' "' . s:realPath(a:dbJsonFile) . '"'
                \ . ' "' . s:realPath(ZFVimIM_cloud_file(a:cloudOption, 'dbFile')) . '"'
                \ . ' "' . s:realPath(ZFVimIM_cloud_file(a:cloudOption, 'dbCountFile')) . '"'
endfunction

function! ZFVimIM_cloud_fixOutputEncoding(msg)
    if has('unix')
        return iconv(a:msg, 'utf-8', &encoding)
    else
        if !exists('s:win32CodePage')
            let s:win32CodePage = system("@echo off && for /f \"tokens=2* delims=: \" %a in ('chcp') do (echo %a)")
            let s:win32CodePage = 'cp' . substitute(s:win32CodePage, '[\r\n]', '', 'g')
        endif
        return iconv(a:msg, s:win32CodePage, &encoding)
    endif
endfunction

function! ZFVimIM_cloud_logInfo(cloudOption)
    let ret = '[ZFVimIM] '
    try
        let ret .= '<' . g:ZFVimIM_db[a:cloudOption['dbIndex']]['name'] . '> '
    endtry
    return ret
endfunction

