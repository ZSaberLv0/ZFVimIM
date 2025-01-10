
" ============================================================
" cloudOption: {
"   'mode' : '(optional) git/local',
"   'cloudInitMode' : '(optional) forceAsync/forceSync/preferAsync/preferSync',
"   'dbId' : '(required) dbId generated by ZFVimIM_dbInit()'
"   'repoPath' : '(required) git/local repo path',
"   'dbFile' : '(required) db file path relative to repoPath, must start with /',
"   'dbCountFile' : '(optional) db count file path relative to repoPath, must start with /',
"   'gitUserEmail' : '(optional) git user email',
"   'gitUserName' : '(optional) git user name',
"   'gitUserToken' : '(optional) git access token or password',
" }
" * for sync upload, when git user info not supplied,
"   we would ask user to input
" * for async upload, when git user info not supplied,
"   nothing would happen
function! ZFVimIM_cloudRegister(cloudOption)
    for key in ['dbId', 'repoPath', 'dbFile']
        if !exists('a:cloudOption[key]')
            echomsg '[ZFVimIM] ZFVimIM_cloudRegister: "' . key . '" is required'
            return
        endif
    endfor
    call add(g:ZFVimIM_cloudOption, a:cloudOption)

    let useAsync = 0
    if ZFVimIM_cloudAsyncAvailable()
        let cloudInitModeGlobal = get(g:, 'ZFVimIM_cloudInitMode', '')
        let cloudInitModeLocal = get(a:cloudOption, 'cloudInitMode', '')
        if 0
        elseif cloudInitModeLocal == 'forceAsync'
            let useAsync = 1
        elseif cloudInitModeLocal == 'forceSync'
            let useAsync = 0
        elseif cloudInitModeGlobal == 'forceAsync'
            let useAsync = 1
        elseif cloudInitModeGlobal == 'forceSync'
            let useAsync = 0
        elseif cloudInitModeLocal == 'preferAsync'
            let useAsync = 1
        elseif cloudInitModeLocal == 'preferSync'
            let useAsync = 0
        elseif cloudInitModeGlobal == 'preferAsync'
            let useAsync = 1
        elseif cloudInitModeGlobal == 'preferSync'
            let useAsync = 0
        else
            let useAsync = 1
        endif
    endif

    if useAsync
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
    redraw!
    for line in s:ZFVimIM_cloud_log
        echo line
    endfor
    return s:ZFVimIM_cloud_log
endfunction
command! -nargs=0 IMCloudLog :call ZFVimIM_cloudLog()

" for debug or develop only
" see dbFunc.dbLoadNormalizePy()
function! ZFVimIM_dbNormalize(dbFile)
    if empty(s:py)
        echo '[ZFVimIM] python not available'
        return
    endif
    let cachePath = CygpathFix_absPath(ZFVimIM_cachePath() . '/ZFVimIM_dbNormalize_' . ZFVimIM_randName())
    if !isdirectory(cachePath)
        silent! call mkdir(cachePath, 'p')
    endif
    let result = system(s:py
                \ . ' "' . CygpathFix_absPath(s:scriptPath . '/dbNormalize.py') . '"'
                \ . ' "' . CygpathFix_absPath(a:dbFile) . '"'
                \ . ' "' . cachePath . '"'
                \ )
    let error = v:shell_error
    if isdirectory(cachePath)
        call ZFVimIM_rm(cachePath)
    endif
    redraw!
    echo '[ZFVimIM] dbNormalize finish'
    if error != 0
        echo result
    endif
endfunction

" param:
" * 0~n : clean g:ZFVimIM_cloudOption[n]
" * cloudOption
" * none : clean all
function! ZFVimIM_dbCleanup(...)
    let cloudOptionList = []
    if a:0 > 0
        if type(a:1) == type(0)
            call add(cloudOptionList, g:ZFVimIM_cloudOption[a:1])
        else
            call add(cloudOptionList, a:1)
        endif
    else
        let cloudOptionList = g:ZFVimIM_cloudOption
    endif

    call ZFVimIM_cloudLogClear()
    for cloudOption in cloudOptionList
        let dbCleanupCachePath = ZFVimIM_cachePath() . '/ZFVimIM_dbCleanup'
        let dbCleanupCmd = ZFVimIM_cloud_dbCleanupCmd(cloudOption, dbCleanupCachePath)
        if empty(dbCleanupCmd)
            continue
        endif
        call ZFVimIM_cloudLogAdd(ZFVimIM_cloudLog_stripSensitive(system(dbCleanupCmd)))
        call ZFVimIM_rm(dbCleanupCachePath)
    endfor
    return ZFVimIM_cloudLog()
endfunction


" ============================================================
if !exists('s:ZFVimIM_cloud_log')
    let s:ZFVimIM_cloud_log = []
endif
function! ZFVimIM_cloudLogAdd(msg)
    call add(s:ZFVimIM_cloud_log, a:msg)
endfunction
function! ZFVimIM_cloudLogClear()
    let s:ZFVimIM_cloud_log = []
endfunction

function! ZFVimIM_cloudLog_stripSensitive(text)
    return substitute(a:text, ':[^:]*@', '@', 'g')
endfunction
function! ZFVimIM_cloudLog_stripSensitiveForJob(jobStatus, textList, type)
    let len = len(a:textList)
    let i = 0
    while i < len
        let a:textList[i] = ZFVimIM_cloudLog_stripSensitive(a:textList[i])
        let i += 1
    endwhile
endfunction


function! ZFVimIM_cloud_gitInfoSupplied(cloudOption)
    return 1
                \ && !empty(get(a:cloudOption, 'gitUserEmail', ''))
                \ && !empty(get(a:cloudOption, 'gitUserName', ''))
                \ && !empty(get(a:cloudOption, 'gitUserToken', ''))
endfunction


" ============================================================
if 0
elseif executable('py3')
    let s:py = 'py3'
elseif executable('python3')
    let s:py = 'python3'
elseif executable('py')
    let s:py = 'py'
elseif executable('python')
    let s:py = 'python'
else
    let s:py = ''
endif

function! ZFVimIM_cloud_isFallback()
    return empty(s:py)
endfunction

function! ZFVimIM_cloud_file(cloudOption, key)
    if empty(get(a:cloudOption, a:key, ''))
        return ''
    else
        return CygpathFix_absPath(a:cloudOption['repoPath'] . '/' . a:cloudOption[a:key])
    endif
endfunction

function! ZFVimIM_cloud_cachePath(cloudOption)
    return CygpathFix_absPath(ZFVimIM_cachePath() . '/ZFVimIM_cloud_' . ZFVimIM_randName())
endfunction

let s:scriptPath = expand('<sfile>:p:h:h') . '/misc'

function! ZFVimIM_cloud_dbDownloadCmd(cloudOption)
    if has('unix')
        return 'sh'
                    \ . ' "' . CygpathFix_absPath(s:scriptPath . '/dbDownload.sh') . '"'
                    \ . ' "' . CygpathFix_absPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
    else
        return '"' . CygpathFix_absPath(s:scriptPath . '/dbDownload.bat') . '"'
                    \ . ' "' . CygpathFix_absPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
    endif
endfunction
function! ZFVimIM_cloud_dbUploadCmd(cloudOption)
    if has('unix')
        return 'sh'
                    \ . ' "' . CygpathFix_absPath(s:scriptPath . '/dbUpload.sh') . '"'
                    \ . ' "' . CygpathFix_absPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
    else
        return '"' . CygpathFix_absPath(s:scriptPath . '/dbUpload.bat') . '"'
                    \ . ' "' . CygpathFix_absPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
    endif
endfunction
function! ZFVimIM_cloud_dbCleanupCheckCmd(cloudOption)
    if has('unix')
        return 'sh'
                    \ . ' "' . CygpathFix_absPath(s:scriptPath . '/dbCleanupCheck.sh') . '"'
                    \ . ' "' . CygpathFix_absPath(a:cloudOption['repoPath']) . '"'
    else
        return '"' . CygpathFix_absPath(s:scriptPath . '/dbCleanupCheck.bat') . '"'
                    \ . ' "' . CygpathFix_absPath(a:cloudOption['repoPath']) . '"'
    endif
endfunction
function! ZFVimIM_cloud_dbCleanupCmd(cloudOption, dbCleanupCachePath)
    if has('unix')
        let path = split(globpath(&rtp, '/misc/git_hard_remove_all_history.sh'), '\n')
        if empty(path)
            return ''
        endif
        let path = substitute(path[0], '[\r\n]', '', 'g')
        let path = CygpathFix_absPath(path)
        return 'sh'
                    \ . ' "' . CygpathFix_absPath(s:scriptPath . '/dbCleanup.sh') . '"'
                    \ . ' "' . CygpathFix_absPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
                    \ . ' "' . CygpathFix_absPath(path) . '"'
                    \ . ' "' . a:dbCleanupCachePath . '"'
    else
        let path = split(globpath(&rtp, '/misc/git_hard_remove_all_history.bat'), '\n')
        if empty(path)
            return ''
        endif
        let path = substitute(path[0], '[\r\n]', '', 'g')
        let path = CygpathFix_absPath(path)
        return '"' . CygpathFix_absPath(s:scriptPath . '/dbCleanup.bat') . '"'
                    \ . ' "' . CygpathFix_absPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
                    \ . ' "' . CygpathFix_absPath(path) . '"'
                    \ . ' "' . a:dbCleanupCachePath . '"'
    endif
endfunction

function! ZFVimIM_cloud_dbLoadCmd(cloudOption, dbLoadCachePath)
    if empty(s:py)
        return ''
    endif
    return s:py
                \ . ' "' . CygpathFix_absPath(s:scriptPath . '/dbLoad.py') . '"'
                \ . ' "' . ZFVimIM_cloud_file(a:cloudOption, 'dbFile') . '"'
                \ . ' "' . ZFVimIM_cloud_file(a:cloudOption, 'dbCountFile') . '"'
                \ . ' "' . CygpathFix_absPath(a:dbLoadCachePath) . '"'
endfunction
function! ZFVimIM_cloud_dbSaveCmd(cloudOption, dbSaveCachePath, cachePath)
    if empty(s:py)
        return ''
    endif
    return s:py
                \ . ' "' . CygpathFix_absPath(s:scriptPath . '/dbSave.py') . '"'
                \ . ' "' . ZFVimIM_cloud_file(a:cloudOption, 'dbFile') . '"'
                \ . ' "' . ZFVimIM_cloud_file(a:cloudOption, 'dbCountFile') . '"'
                \ . ' "' . CygpathFix_absPath(a:dbSaveCachePath) . '"'
                \ . ' "' . CygpathFix_absPath(a:cachePath) . '"'
endfunction
function! ZFVimIM_cloud_dbEditToFile(cloudOption, dbSaveCachePath, dbEdit)
    let path = CygpathFix_absPath(a:dbSaveCachePath)
    let contents = []
    for item in a:dbEdit
        call add(contents, printf('%s %s %s'
                    \ , item['action']
                    \ , substitute(item['key'], ' ', '\\ ', 'g')
                    \ , substitute(item['word'], ' ', '\\ ', 'g')
                    \ ))
    endfor
    call writefile(contents, a:dbSaveCachePath)
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
    let dbIndex = ZFVimIM_dbIndexForId(a:cloudOption['dbId'])
    if dbIndex < 0
        return '[ZFVimIM]'
    else
        return '[ZFVimIM] <' . g:ZFVimIM_db[dbIndex]['name'] . '> '
    endif
endfunction


" ============================================================
" cloud lock logic
" since multiple vim instance may processing same db repo,
" which would cause modify race,
" we use a global lock file to prevent it,
" when the global lock file exists (and not timeout),
" it's considered there's other vim instance modifying the db repo,
" then we would delay to wait
" the lock timeout is used to fix that,
" if other vim instance crash during modifying db repo,
" the global lock file would remain on the disk causing
" other vim instance can never get updated
"
" possible values:
" <= 0 : disable lock
" > 0 : lock timeout after specified time
if !exists('g:ZFVimIM_cloud_lockTimeout')
    let g:ZFVimIM_cloud_lockTimeout=1*60*60*1000
endif
function! ZFVimIM_cloud_lockAcquired()
    return get(s:, 'ZFVimIM_cloud_lockAcquired', 0)
endfunction
" ZFVimIM_cloud_lockAcquire() and ZFVimIM_cloud_lockRelease() must be paired
function! ZFVimIM_cloud_lockAcquire()
    let s:ZFVimIM_cloud_lockAcquiredFlag = get(s:, 'ZFVimIM_cloud_lockAcquiredFlag', 0) + 1
    if s:ZFVimIM_cloud_lockAcquiredFlag != 1
        return
    endif

    if g:ZFVimIM_cloud_lockTimeout <= 0
        let s:ZFVimIM_cloud_lockAcquired = 1
        return
    endif

    let lockInfo = s:lockFileRead()
    let curTime = localtime() * 1000
    if empty(lockInfo) || curTime > lockInfo['timestamp'] + g:ZFVimIM_cloud_lockTimeout
        call s:lockFileWrite()
        let s:ZFVimIM_cloud_lockAcquired = 1
    else
        let s:ZFVimIM_cloud_lockAcquired = 0
    endif
endfunction
function! ZFVimIM_cloud_lockRelease()
    let s:ZFVimIM_cloud_lockAcquiredFlag = s:ZFVimIM_cloud_lockAcquiredFlag - 1
    if s:ZFVimIM_cloud_lockAcquiredFlag != 0
        return
    endif
    if s:ZFVimIM_cloud_lockAcquired
        let s:ZFVimIM_cloud_lockAcquired = 0
        let lockInfo = s:lockFileRead()
        if !empty(lockInfo) && lockInfo['pid'] == getpid()
            call delete(s:lockFile())
        endif
    endif
endfunction
function! s:lockFile()
    return ZFVimIM_cachePath() . '/ZFVimIM_cloud.lock'
endfunction
" return: {
"   'pid' : xx,
"   'timestamp' : xx,
" }
function! s:lockFileRead()
    let lockFile = s:lockFile()
    if !filereadable(lockFile)
        return {}
    endif
    let contents = readfile(lockFile)
    let pid = str2nr(get(contents, 0, 0))
    let timestamp = str2nr(get(contents, 1, 0))
    if pid > 0 && timestamp > 0
        return {
                    \   'pid' : pid,
                    \   'timestamp' : timestamp,
                    \ }
    else
        return {}
    endif
endfunction
function! s:lockFileWrite()
    let lockFile = s:lockFile()
    call writefile([
                \   getpid(),
                \   localtime() * 1000,
                \ ], lockFile)
endfunction

