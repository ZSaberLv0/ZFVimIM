
" ============================================================
" <= 0 : disable
" > 0 : delay miliseconds and upload
if !exists('g:ZFVimIM_cloudAsync_enable')
    let g:ZFVimIM_cloudAsync_enable=5000
endif
if !exists('g:ZFVimIM_cloudAsync_timeout')
    let g:ZFVimIM_cloudAsync_timeout=30000
endif
if !exists('g:ZFVimIM_cloudAsync_autoCleanup')
    let g:ZFVimIM_cloudAsync_autoCleanup=30
endif
if !exists('g:ZFVimIM_cloudAsync_autoInit')
    let g:ZFVimIM_cloudAsync_autoInit=(g:ZFVimIM_cloudAsync_enable > 0)
endif
if !exists('g:ZFVimIM_cloudAsync_outputTo')
    let g:ZFVimIM_cloudAsync_outputTo = {
                \   'outputType' : 'statusline',
                \   'outputId' : 'ZFVimIM_cloud_async',
                \ }
endif


" ============================================================
function! ZFVimIM_cloudAsyncAvailable()
    if !exists('s:uploadAsyncAvailableCache')
        let s:uploadAsyncAvailableCache = exists('*ZFJobAvailable') && ZFJobAvailable()
    endif
    return s:uploadAsyncAvailableCache
endfunction


function! ZFVimIM_initAsync(cloudOption)
    call s:initAsync(a:cloudOption)
endfunction


function! ZFVimIM_downloadAsync(cloudOption)
    call s:uploadAsync(a:cloudOption, 'download')
endfunction
function! ZFVimIM_downloadAllAsync()
    call ZFVimIM_downloadAllAsyncCancel()
    for cloudOption in g:ZFVimIM_cloudOption
        call ZFVimIM_downloadAsync(cloudOption)
    endfor
endfunction
function! ZFVimIM_downloadAllAsyncCancel()
    call s:UA_cancel()
endfunction


function! ZFVimIM_uploadAsync(cloudOption)
    call s:uploadAsync(a:cloudOption, 'askIfNoGitInfo')
endfunction
function! ZFVimIM_uploadAllAsync()
    for cloudOption in g:ZFVimIM_cloudOption
        call s:uploadAsync(cloudOption, 'askIfNoGitInfo')
    endfor
endfunction
function! ZFVimIM_uploadAllAsyncCancel()
    call s:UA_cancel()
endfunction


" ============================================================
augroup ZFVimIM_cloud_async_augroup
    autocmd!
    autocmd User ZFVimIM_event_OnUpdateDb
                \  if g:ZFVimIM_cloudAsync_enable > 0 && ZFVimIM_cloudAsyncAvailable()
                \|     call s:autoUploadAsync()
                \| endif
    autocmd VimEnter * call s:UA_autoInit()
augroup END

" ============================================================
" {
"   'dbId' : {
"     'cloudOption' : {},
"     'initOnly' : 0,
"     'downloadOnly' : 0,
"     'jobId' : -1,
"     'dbLoadJsonFile' : '',
"     'dbSaveJsonFile' : '',
"     'dbNew' : {}, // valid only after download success
"   },
" }
let s:UA_taskMap = {}

function! s:UA_autoInit()
    if g:ZFVimIM_cloudAsync_autoInit
                \ && ZFVimIM_cloudAsyncAvailable()
                \ && (has('python') || has('python3'))
        let g:ZFVimIM_cloudForceAsync=1
        call ZFVimIME_init()
        unlet g:ZFVimIM_cloudForceAsync
    endif
endfunction
function! s:UA_cancel()
    call s:autoUploadAsyncCancel()
    let taskMap = s:UA_taskMap
    let s:UA_taskMap = {}
    for task in values(taskMap)
        if task['jobId'] > 0
            call ZFGroupJobStop(task['jobId'])
        endif
    endfor
endfunction

let s:autoUploadAsyncRetryTimeInc = 1
let s:autoUploadAsyncDelayTimerId = -1
function! s:autoUploadAsync()
    if g:ZFVimIM_cloudAsync_enable <= 0
        return
    endif
    if !has('timers')
        call s:autoUploadAsyncAction()
        return
    endif
    if s:autoUploadAsyncDelayTimerId != -1
        call timer_stop(s:autoUploadAsyncDelayTimerId)
    endif
    let s:autoUploadAsyncDelayTimerId = timer_start(g:ZFVimIM_cloudAsync_enable * s:autoUploadAsyncRetryTimeInc, function('s:autoUploadAsync_timeout'))
endfunction
function! s:autoUploadAsyncCancel()
    if s:autoUploadAsyncDelayTimerId != -1
        call timer_stop(s:autoUploadAsyncDelayTimerId)
        let s:autoUploadAsyncDelayTimerId = -1
    endif
    let taskMap = s:UA_taskMap
    let s:UA_taskMap = {}
    for dbId in keys(taskMap)
        let task = taskMap[dbId]
        if task['jobId'] != -1
            call ZFGroupJobStop(task['jobId'])
        endif
        if !empty(task['dbNew'])
            let db = ZFVimIM_dbForId(dbId)
            if !empty(db)
                call extend(db['dbEdit'], task['dbNew']['dbEdit'], 0)
            endif
        endif
    endfor
    call ZFStatuslineLogClear()
endfunction
function! s:autoUploadAsync_timeout(...)
    let s:autoUploadAsyncDelayTimerId = -1
    call s:autoUploadAsyncAction()
endfunction
function! s:autoUploadAsyncAction()
    for cloudOption in g:ZFVimIM_cloudOption
        call s:uploadAsync(cloudOption, 'autoUpload')
    endfor
endfunction


let g:ZFVimIM_cloudAsync_log = []
function! s:cloudAsyncLog(groupJobStatus, msg)
    call add(g:ZFVimIM_cloudAsync_log, a:msg)
    if !empty(a:groupJobStatus)
        call ZFJobOutput(a:groupJobStatus, a:msg)
    endif
endfunction


function! s:UA_gitInfoPrepare(cloudOption, downloadOnly)
    if !isdirectory(get(a:cloudOption, 'repoPath', ''))
        redraw!
        call s:cloudAsyncLog({}, ZFVimIM_cloud_logInfo(a:cloudOption) . 'invalid repoPath: ' . get(a:cloudOption, 'repoPath', ''))
        return 0
    endif
    if filewritable(ZFVimIM_cloud_file(a:cloudOption, 'dbFile')) != 1
        redraw!
        call s:cloudAsyncLog({}, ZFVimIM_cloud_logInfo(a:cloudOption) . 'invalid dbFile: ' . ZFVimIM_cloud_file(a:cloudOption, 'dbFile'))
        return 0
    endif
    if a:downloadOnly
        return 1
    endif
    if empty(a:cloudOption['gitUserEmail'])
        redraw!
        call s:cloudAsyncLog({}, ZFVimIM_cloud_logInfo(a:cloudOption) . 'missing gitUserEmail')
        return 0
    endif
    if empty(a:cloudOption['gitUserName'])
        redraw!
        call s:cloudAsyncLog({}, ZFVimIM_cloud_logInfo(a:cloudOption) . 'missing gitUserName')
        return 0
    endif
    if empty(a:cloudOption['gitUserToken'])
        redraw!
        call s:cloudAsyncLog({}, ZFVimIM_cloud_logInfo(a:cloudOption) . 'missing gitUserToken')
        return 0
    endif
    return 1
endfunction

function! s:initAsync(cloudOption)
    call s:uploadAsync(a:cloudOption, 'init')
endfunction

" mode:
" * init
" * download
" * askIfNoGitInfo
" * autoUpload
function! s:uploadAsync(cloudOption, mode)
    let dbId = a:cloudOption['dbId']
    let db = ZFVimIM_dbForId(dbId)
    if exists('s:UA_taskMap[dbId]') || empty(db)
        return
    endif
    if a:mode == 'autoUpload' && empty(db['dbEdit'])
        return
    endif

    let g:ZFVimIM_cloudAsync_log = []

    let downloadOnly = (a:mode == 'download')
    let initOnly = (a:mode == 'init') || !executable('git')
    let askIfNoGitInfo = (a:mode == 'askIfNoGitInfo')

    if !initOnly && !downloadOnly && empty(db['dbEdit'])
        call s:cloudAsyncLog({}, ZFVimIM_cloud_logInfo(a:cloudOption) . 'canceled: nothing to push')
        return
    endif
    if !ZFVimIM_cloudAsyncAvailable()
        call s:cloudAsyncLog({}, ZFVimIM_cloud_logInfo(a:cloudOption) . 'canceled: async mode not available')
        return
    endif
    if !initOnly && !s:UA_gitInfoPrepare(a:cloudOption, downloadOnly)
        if askIfNoGitInfo
            call ZFVimIM_uploadSync(a:cloudOption)
        endif
        return
    endif

    let task = {
                \   'cloudOption' : a:cloudOption,
                \   'initOnly' : initOnly,
                \   'downloadOnly' : downloadOnly,
                \   'jobId' : -1,
                \   'dbLoadJsonFile' : tempname(),
                \   'dbSaveJsonFile' : tempname(),
                \   'dbNew' : {},
                \ }
    let s:UA_taskMap[db['dbId']] = task

    let dbLoadCmd = ZFVimIM_cloud_dbLoadCmd(a:cloudOption, task['dbLoadJsonFile'])
    let dbSaveCmd = ZFVimIM_cloud_dbSaveCmd(a:cloudOption, task['dbSaveJsonFile'])
    let groupJobOption = {
                \   'jobList' : [],
                \   'onExit' : ZFJobFunc(function('s:UA_onExit'), [db['dbId']]),
                \   'jobTimeout' : g:ZFVimIM_cloudAsync_timeout,
                \   'outputTo' : g:ZFVimIM_cloudAsync_outputTo,
                \ }
    if !initOnly
        call add(groupJobOption['jobList'], [{
                    \       'jobCmd' : ZFVimIM_cloud_dbDownloadCmd(a:cloudOption),
                    \       'onOutput' : ZFJobFunc(function('s:UA_dbDownloadOnOutput'), [db['dbId']]),
                    \       'onExit' : ZFJobFunc(function('s:UA_dbDownloadOnExit'), [db['dbId']]),
                    \ }])
    endif
    if !empty(dbLoadCmd)
        call add(groupJobOption['jobList'], [{
                    \   'jobCmd' : dbLoadCmd,
                    \   'onOutput' : ZFJobFunc(function('s:UA_dbLoadOnOutput'), [db['dbId']]),
                    \   'onExit' : ZFJobFunc(function('s:UA_dbLoadOnExit'), [db['dbId']]),
                    \ }])
    else
        call add(groupJobOption['jobList'], [{
                    \   'jobCmd' : ZFJobFunc(function('s:UA_dbLoadFallback'), [db['dbId']]),
                    \ }])
    endif
    if !initOnly && !downloadOnly
        if !empty(dbSaveCmd)
            call add(groupJobOption['jobList'], [{
                        \   'jobCmd' : dbSaveCmd,
                        \   'onOutput' : ZFJobFunc(function('s:UA_dbSaveOnOutput'), [db['dbId']]),
                        \   'onExit' : ZFJobFunc(function('s:UA_dbSaveOnExit'), [db['dbId']]),
                        \ }])
        else
            " nothing to do
            " should be done at s:UA_dbLoadFallback
        endif
        call add(groupJobOption['jobList'], [{
                    \   'jobCmd' : ZFVimIM_cloud_dbUploadCmd(a:cloudOption),
                    \   'onOutput' : ZFJobFunc(function('s:UA_dbUploadOnOutput'), [db['dbId']]),
                    \ }])

        if g:ZFVimIM_cloudAsync_autoCleanup > 0 && ZFVimIM_cloud_gitInfoSupplied(a:cloudOption)
            let dbCleanupCmd = ZFVimIM_cloud_dbCleanupCmd(a:cloudOption)
            if !empty(dbCleanupCmd)
                call add(groupJobOption['jobList'], [{
                            \   'jobCmd' : ZFVimIM_cloud_dbCleanupCheckCmd(a:cloudOption),
                            \   'onOutput' : ZFJobFunc(function('s:UA_dbCleanupCheckOnOutput'), [db['dbId']]),
                            \ }])

                if get(db['implData'], '_dbCleanupHistory', 0) >= g:ZFVimIM_cloudAsync_autoCleanup
                    call add(groupJobOption['jobList'], [{
                                \   'jobCmd' : dbCleanupCmd,
                                \   'onOutput' : ZFJobFunc(function('s:UA_dbCleanupOnOutput'), [db['dbId']]),
                                \ }])
                    let groupJobOption['jobTimeout'] += g:ZFVimIM_cloudAsync_timeout
                endif
            endif
        endif
    endif

    let task['jobId'] = ZFGroupJobStart(groupJobOption)
    if task['jobId'] == -1
        if exists("s:UA_taskMap[db['dbId']]")
            unlet s:UA_taskMap[db['dbId']]
        endif
        return
    endif

    call s:cloudAsyncLog(ZFGroupJobStatus(task['jobId']), ZFVimIM_cloud_logInfo(a:cloudOption) . 'updating...')
endfunction

function! s:UA_dbDownloadOnOutput(dbId, jobStatus, text, type)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'updating : ' . a:text)
endfunction
function! s:UA_dbDownloadOnExit(dbId, jobStatus, exitCode)
    if a:exitCode != '0'
        return
    endif
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'merging...')
endfunction

function! s:UA_dbLoadFallback(dbId, jobStatus)
    let task = get(s:UA_taskMap, a:dbId, {})
    let db = ZFVimIM_dbForId(a:dbId)
    if empty(task) || empty(db)
        return {
                    \   'output' : 'error',
                    \   'exitCode' : '-1',
                    \ }
    endif

    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'merging (no python)...')
    let cloudOption = task['cloudOption']
    let dbFile = ZFVimIM_cloud_file(cloudOption, 'dbFile')
    let dbCountFile = ZFVimIM_cloud_file(cloudOption, 'dbCountFile')
    let dbNew = {}
    call ZFVimIM_dbLoad(dbNew, dbFile, dbCountFile)
    let dbNew['dbEdit'] = db['dbEdit']
    let db['dbEdit'] = []
    let task['dbNew'] = dbNew
    if task['initOnly'] || task['downloadOnly']
        let db['dbMap'] = dbNew['dbMap']
        let db['dbKeyMap'] = dbNew['dbKeyMap']
    else
        call ZFVimIM_dbEditApply(dbNew, dbNew['dbEdit'])
        call ZFVimIM_dbSave(dbNew, dbFile, dbCountFile)
    endif
    return {
                \   'output' : '',
                \   'exitCode' : '0',
                \ }
endfunction

function! s:UA_dbLoadOnOutput(dbId, jobStatus, text, type)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'merging : ' . a:text)
endfunction
function! s:UA_dbLoadOnExit(dbId, jobStatus, exitCode)
    if a:exitCode != '0'
        return
    endif
    let task = get(s:UA_taskMap, a:dbId, {})
    let db = ZFVimIM_dbForId(a:dbId)
    if empty(task) || empty(db)
        return
    endif

    if !empty(db['dbMap'])
        let dbNew = {
                    \   'dbMap' : db['dbMap'],
                    \   'dbKeyMap' : db['dbKeyMap'],
                    \ }
    else
        call ZFVimIM_DEBUG_profileStart('dbLoadJsonFile')
        let dbLoadJsonFileContent = readfile(task['dbLoadJsonFile'])[0]
        call ZFVimIM_DEBUG_profileStop()
        call ZFVimIM_DEBUG_profileStart('dbLoadJson')
        let dbNew = json_decode(dbLoadJsonFileContent)
        call ZFVimIM_DEBUG_profileStop()
    endif

    if task['initOnly']
        let db['dbMap'] = dbNew['dbMap']
        let db['dbKeyMap'] = dbNew['dbKeyMap']
    else
        call ZFVimIM_dbEditApply(dbNew, db['dbEdit'])
        let dbNew['dbEdit'] = db['dbEdit']
        let db['dbEdit'] = []
        let task['dbNew'] = dbNew
        if 0
            " using vim's state,
            " takes long time to json_encode()
            call ZFVimIM_DEBUG_profileStart('dbSaveJson')
            let dbSaveJsonFileContent = [json_encode(dbNew)]
            call ZFVimIM_DEBUG_profileStop()
        else
            " let python to load>apply>save,
            " may lost some local changes
            call ZFVimIM_DEBUG_profileStart('dbSaveJson')
            let dbSaveJsonFileContent = [json_encode({
                        \   'dbEdit' : dbNew['dbEdit'],
                        \ })]
            call ZFVimIM_DEBUG_profileStop()
        endif
        call ZFVimIM_DEBUG_profileStart('dbSaveJsonFile')
        call writefile(dbSaveJsonFileContent, task['dbSaveJsonFile'])
        call ZFVimIM_DEBUG_profileStop()

        if !empty(dbNew['dbEdit'])
            let logHead = ZFVimIM_cloud_logInfo(task['cloudOption'])
            let groupJobStatus = ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId'])
            call s:cloudAsyncLog(groupJobStatus, logHead . 'changes:')
            for dbEdit in dbNew['dbEdit']
                call s:cloudAsyncLog(groupJobStatus, logHead . '  ' . printf('%6s', dbEdit['action']) . "\t" . dbEdit['key'] . ' ' . dbEdit['word'])
            endfor
        endif
    endif
endfunction

function! s:UA_dbSaveOnOutput(dbId, jobStatus, text, type)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'merging : ' . a:text)
endfunction
function! s:UA_dbSaveOnExit(dbId, jobStatus, exitCode)
    if a:exitCode != '0'
        return
    endif
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'pushing...')
endfunction

function! s:UA_dbUploadOnOutput(dbId, jobStatus, text, type)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'pushing : ' . a:text)
endfunction

function! s:UA_dbCleanupCheckOnOutput(dbId, jobStatus, text, type)
    let task = get(s:UA_taskMap, a:dbId, {})
    let db = ZFVimIM_dbForId(a:dbId)
    if empty(task) || empty(db)
        return
    endif
    let history = substitute(a:text, '[\r\n]', '', 'g')
    let history = str2nr(history)
    let db['implData']['_dbCleanupHistory'] = history
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'history : ' . history)
endfunction
function! s:UA_dbCleanupOnOutput(dbId, jobStatus, text, type)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'cleaning : ' . a:text)
endfunction

function! s:UA_onExit(dbId, groupJobStatus, exitCode)
    while 1
        let task = get(s:UA_taskMap, a:dbId, {})
        if empty(task)
            break
        endif
        unlet s:UA_taskMap[a:dbId]

        let db = ZFVimIM_dbForId(a:dbId)
        if empty(db)
            break
        endif

        if a:exitCode == '0'
            call s:cloudAsyncLog(a:groupJobStatus, ZFVimIM_cloud_logInfo(task['cloudOption']) . 'update success')
            let s:autoUploadAsyncRetryTimeInc = 1
            if !empty(db['dbEdit'])
                call s:autoUploadAsync()
            endif
            break
        endif

        let dbNew = task['dbNew']
        if exists("dbNew['dbEdit']")
            call extend(db['dbEdit'], dbNew['dbEdit'], 0)
        endif

        call s:cloudAsyncLog(a:groupJobStatus, ZFVimIM_cloud_logInfo(task['cloudOption']) . 'update failed, exitCode: ' . a:exitCode . ', detailed log:')
        for output in a:groupJobStatus['jobOutput']
            call s:cloudAsyncLog(a:groupJobStatus, '    ' . output)
        endfor
        call s:cloudAsyncLog(a:groupJobStatus, ZFVimIM_cloud_logInfo(task['cloudOption']) . 'update failed, exitCode: ' . a:exitCode)
        let s:autoUploadAsyncRetryTimeInc = s:autoUploadAsyncRetryTimeInc * 2
        call s:autoUploadAsync()
        break
    endwhile

    if(!empty(task))
        call delete(task['dbLoadJsonFile'])
        call delete(task['dbSaveJsonFile'])
    endif
    call ZFJobOutputCleanup(a:groupJobStatus)
endfunction

