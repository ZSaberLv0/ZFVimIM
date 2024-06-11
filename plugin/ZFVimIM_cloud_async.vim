
" ============================================================
" <= 0 : disable
" 1 : upload immediately
" > 1 : delay miliseconds and upload
if !exists('g:ZFVimIM_cloudAsync_enable')
    let g:ZFVimIM_cloudAsync_enable=30000
endif
if !exists('g:ZFVimIM_cloudAsync_timeout')
    let g:ZFVimIM_cloudAsync_timeout=60000
endif
if !exists('g:ZFVimIM_cloudAsync_autoCleanup')
    let g:ZFVimIM_cloudAsync_autoCleanup=30
endif
if !exists('g:ZFVimIM_cloudAsync_autoCleanup_timeout')
    let g:ZFVimIM_cloudAsync_autoCleanup_timeout=g:ZFVimIM_cloudAsync_timeout
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
    if !exists('s:cloudAsyncAvailable')
        let s:cloudAsyncAvailable = (exists('*ZFJobAvailable') && ZFJobAvailable())
                    \ || (exists('*ZFJobTimerAvailable') && ZFJobTimerAvailable() && get(g:, 'ZFVimIM_cloudAsync_jobFallback', 0))
    endif
    return s:cloudAsyncAvailable
endfunction


function! ZFVimIM_initAsync(cloudOption)
    call s:initAsync(a:cloudOption)
endfunction


function! ZFVimIM_downloadAsync(cloudOption)
    call s:uploadAsync(a:cloudOption, 'download')
endfunction
function! ZFVimIM_downloadAllAsync()
    call ZFVimIM_downloadAllAsyncCancel()
    call ZFVimIM_cloud_lockAcquire()
    for cloudOption in g:ZFVimIM_cloudOption
        call ZFVimIM_downloadAsync(cloudOption)
    endfor
    call ZFVimIM_cloud_lockRelease()
endfunction
function! ZFVimIM_downloadAllAsyncCancel()
    call s:UA_cancel()
endfunction


function! ZFVimIM_uploadAsync(cloudOption)
    call s:uploadAsync(a:cloudOption, 'upload')
endfunction
function! ZFVimIM_uploadAllAsync()
    for cloudOption in g:ZFVimIM_cloudOption
        call s:uploadAsync(cloudOption, 'upload')
    endfor
endfunction
function! ZFVimIM_uploadAllAsyncCancel()
    call s:UA_cancel()
endfunction


" ============================================================
" {
"   'dbId' : {
"     'mode' : 'init/download/upload/autoUpload',
"     'cloudOption' : {},
"     'jobId' : -1,
"     'cachePath' : '',
"     'dbMapNew' : {}, // if update success, change cur db to this
"     'dbEdit' : [], // dbEdit being uploading
"   },
" }
let s:UA_taskMap = {}

function! s:UA_autoInit()
    if g:ZFVimIM_cloudAsync_autoInit
                \ && ZFVimIM_cloudAsyncAvailable()
                \ && !ZFVimIM_cloud_isFallback()
        let cloudInitMode = get(g:, 'ZFVimIM_cloudInitMode', '')
        let g:ZFVimIM_cloudInitMode = 'forceAsync'
        call ZFVimIME_init()
        let g:ZFVimIM_cloudInitMode = cloudInitMode
    endif
endfunction
function! s:UA_cancel()
    call s:autoUploadAsyncCancel()
    let taskMap = s:UA_taskMap
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
                \ || (g:ZFVimIM_cloudAsync_enable * s:autoUploadAsyncRetryTimeInc) == 1
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
    for dbId in keys(taskMap)
        let task = taskMap[dbId]
        if task['jobId'] != -1
            call ZFGroupJobStop(task['jobId'])
        endif
    endfor
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


function! s:cloudAsyncLog(groupJobStatus, msg)
    call ZFVimIM_cloudLogAdd(a:msg)
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
" * upload
" * autoUpload
function! s:uploadAsync(cloudOption, mode)
    let dbId = a:cloudOption['dbId']
    let db = ZFVimIM_dbForId(dbId)
    if exists('s:UA_taskMap[dbId]') || empty(db)
        return
    endif

    call ZFVimIM_cloudLogClear()

    let applyOnly = (get(a:cloudOption, 'mode', '') == 'local')
    let downloadOnly = (a:mode == 'download')
    let initOnly = (a:mode == 'init') || !executable('git')
    let askIfNoGitInfo = (a:mode == 'upload')

    if !initOnly && !downloadOnly && !empty(db['dbMap']) && empty(db['dbEdit'])
        call s:cloudAsyncLog({}, ZFVimIM_cloud_logInfo(a:cloudOption) . 'canceled: nothing to upload')
        return
    endif
    if !ZFVimIM_cloudAsyncAvailable()
        call s:cloudAsyncLog({}, ZFVimIM_cloud_logInfo(a:cloudOption) . 'canceled: async mode not available')
        return
    endif
    if !initOnly && !applyOnly && !s:UA_gitInfoPrepare(a:cloudOption, downloadOnly)
        if askIfNoGitInfo
            call ZFVimIM_uploadSync(a:cloudOption)
        endif
        return
    endif

    let task = {
                \   'mode' : a:mode,
                \   'cloudOption' : a:cloudOption,
                \   'jobId' : -1,
                \   'cachePath' : ZFVimIM_cloud_cachePath(a:cloudOption),
                \   'dbMapNew' : {},
                \   'dbEdit' : [],
                \ }
    silent! call mkdir(task['cachePath'], 'p')
    let s:UA_taskMap[db['dbId']] = task
    let task['dbEdit'] = db['dbEdit']
    let db['dbEdit'] = []

    let dbLoadCmd = ZFVimIM_cloud_dbLoadCmd(a:cloudOption, task['cachePath'] . '/dbLoadCache')
    if initOnly && empty(dbLoadCmd) && empty(db['dbMap'])
        " load without python takes a long time,
        " do not load during init
        return
    endif

    let groupJobOption = {
                \   'jobList' : [],
                \   'onExit' : ZFJobFunc(function('s:UA_onExit'), [db['dbId']]),
                \   'jobTimeout' : g:ZFVimIM_cloudAsync_timeout,
                \   'outputTo' : g:ZFVimIM_cloudAsync_outputTo,
                \ }

    " lock logic
    " release on group job onExit
    call ZFVimIM_cloud_lockAcquire()

    " download and load to vim
    if !initOnly && !applyOnly && ZFVimIM_cloud_lockAcquired()
        call s:UATask_dbDownload(a:cloudOption, task, groupJobOption, db)
    endif
    " for performance, we only load if db is empty
    if empty(db['dbMap'])
        let dbLoadFlag = 1
        call s:UATask_dbLoad(a:cloudOption, task, groupJobOption, db)
    else
        let dbLoadFlag = 0
    endif
    " save to file and upload
    if !initOnly && !downloadOnly && !empty(task['dbEdit']) && ZFVimIM_cloud_lockAcquired()
        call s:UATask_dbSave(a:cloudOption, task, groupJobOption, db)
        if !applyOnly
            call s:UATask_dbUpload(a:cloudOption, task, groupJobOption, db)
        endif
    endif
    " reload if _dbLoadRequired
    if !dbLoadFlag && db['implData']['_dbLoadRequired']
        call s:UATask_dbLoad(a:cloudOption, task, groupJobOption, db)
    endif

    " finally, start the job
    call s:cloudAsyncLog(ZFGroupJobStatus(task['jobId']), ZFVimIM_cloud_logInfo(a:cloudOption) . 'updating...')
    let task['jobId'] = ZFGroupJobStart(groupJobOption)
    if task['jobId'] == -1
        if exists("s:UA_taskMap[db['dbId']]")
            unlet s:UA_taskMap[db['dbId']]
        endif
        return
    endif
endfunction

function! s:UATask_dbDownload(cloudOption, task, groupJobOption, db)
    call add(a:groupJobOption['jobList'], [{
                \   'jobCmd' : ZFVimIM_cloud_dbDownloadCmd(a:cloudOption),
                \   'onOutputFilter' : function('ZFVimIM_cloudLog_stripSensitiveForJob'),
                \   'onOutput' : ZFJobFunc(function('s:UA_dbDownloadOnOutput'), [a:db['dbId']]),
                \ }])
endfunction
function! s:UATask_dbLoad(cloudOption, task, groupJobOption, db)
    let dbLoadCmd = ZFVimIM_cloud_dbLoadCmd(a:cloudOption, a:task['cachePath'] . '/dbLoadCache')
    if empty(dbLoadCmd)
        call add(a:groupJobOption['jobList'], [{
                    \   'jobCmd' : ZFJobFunc(function('s:UA_dbLoadFallback'), [a:db['dbId']]),
                    \ }])
    else
        call add(a:groupJobOption['jobList'], [{
                    \   'jobCmd' : dbLoadCmd,
                    \   'onEnter' : ZFJobFunc(function('s:UA_dbLoadOnEnter'), [a:db['dbId']]),
                    \   'onExit' : ZFJobFunc(function('s:UA_dbLoadOnExit'), [a:db['dbId']]),
                    \   'onOutput' : ZFJobFunc(function('s:UA_dbLoadOnOutput'), [a:db['dbId']]),
                    \ }])
        let dbLoadPartTasks = []
        for c_ in range(char2nr('a'), char2nr('z'))
            let c = nr2char(c_)
            call add(dbLoadPartTasks, {
                        \   'jobCmd' : 10,
                        \   'onOutputFilter' : function('s:UA_dbLoadPartOnOutputFilter'),
                        \   'onExit' : ZFJobFunc(function('s:UA_dbLoadPartOnExit'), [a:db['dbId'], c]),
                        \ })
        endfor
        call add(a:groupJobOption['jobList'], dbLoadPartTasks)
    endif
endfunction
function! s:UATask_dbSave(cloudOption, task, groupJobOption, db)
    let dbSaveCmd = ZFVimIM_cloud_dbSaveCmd(a:cloudOption, a:task['cachePath'] . '/dbSaveCache', a:task['cachePath'])
    if empty(dbSaveCmd)
        call add(a:groupJobOption['jobList'], [{
                    \   'jobCmd' : ZFJobFunc(function('s:UA_dbSaveFallback'), [a:db['dbId']]),
                    \ }])
    else
        call add(a:groupJobOption['jobList'], [{
                    \   'jobCmd' : dbSaveCmd,
                    \   'onEnter' : ZFJobFunc(function('s:UA_dbSaveOnEnter'), [a:db['dbId']]),
                    \   'onOutput' : ZFJobFunc(function('s:UA_dbSaveOnOutput'), [a:db['dbId']]),
                    \ }])
    endif
endfunction
function! s:UATask_dbUpload(cloudOption, task, groupJobOption, db)
    call add(a:groupJobOption['jobList'], [{
                \   'jobCmd' : ZFVimIM_cloud_dbUploadCmd(a:cloudOption),
                \   'onEnter' : ZFJobFunc(function('s:UA_dbUploadOnEnter'), [a:db['dbId']]),
                \   'onOutputFilter' : function('ZFVimIM_cloudLog_stripSensitiveForJob'),
                \   'onOutput' : ZFJobFunc(function('s:UA_dbUploadOnOutput'), [a:db['dbId']]),
                \ }])

    if g:ZFVimIM_cloudAsync_autoCleanup > 0 && ZFVimIM_cloud_gitInfoSupplied(a:cloudOption)
        let dbCleanupCmd = ZFVimIM_cloud_dbCleanupCmd(a:cloudOption, a:task['cachePath'] . '/dbCleanupCache')
        if !empty(dbCleanupCmd)
            call add(a:groupJobOption['jobList'], [{
                        \   'jobCmd' : ZFVimIM_cloud_dbCleanupCheckCmd(a:cloudOption),
                        \   'onOutput' : ZFJobFunc(function('s:UA_dbCleanupCheckOnOutput'), [a:db['dbId']]),
                        \ }])

            if get(a:db['implData'], '_dbCleanupHistory', 0) >= g:ZFVimIM_cloudAsync_autoCleanup
                call add(a:groupJobOption['jobList'], [{
                            \   'jobCmd' : dbCleanupCmd,
                            \   'onOutputFilter' : function('ZFVimIM_cloudLog_stripSensitiveForJob'),
                            \   'onOutput' : ZFJobFunc(function('s:UA_dbCleanupOnOutput'), [a:db['dbId']]),
                            \ }])
                let a:groupJobOption['jobTimeout'] += g:ZFVimIM_cloudAsync_autoCleanup_timeout
            endif
        endif
    endif
endfunction

function! s:UA_dbDownloadOnOutput(dbId, jobStatus, textList, type)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    for text in a:textList
        call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'updating : ' . text)
    endfor
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
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'loading (fallback)...')

    let dbFile = ZFVimIM_cloud_file(task['cloudOption'], 'dbFile')
    let dbCountFile = ZFVimIM_cloud_file(task['cloudOption'], 'dbCountFile')
    call extend(task['dbEdit'], db['dbEdit'])
    call ZFVimIM_dbLoad(db, dbFile, dbCountFile)
    call ZFVimIM_dbEditApply(db, task['dbEdit'])

    return {
                \   'output' : '',
                \   'exitCode' : '0',
                \ }
endfunction

function! s:UA_dbLoadOnEnter(dbId, jobStatus)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'loading...')
endfunction
function! s:UA_dbLoadOnExit(dbId, jobStatus, exitCode)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    if a:exitCode != '0'
        return
    endif
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'loading parts...')
endfunction
function! s:UA_dbLoadOnOutput(dbId, jobStatus, textList, type)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    for text in a:textList
        call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'loading: ' . text)
    endfor
endfunction

function! s:UA_dbLoadPartOnOutputFilter(jobStatus, textList, type)
    if !empty(a:textList)
        call remove(a:textList, 0, -1)
    endif
endfunction
function! s:UA_dbLoadPartOnExit(dbId, c, jobStatus, exitCode)
    let task = get(s:UA_taskMap, a:dbId, {})
    let db = ZFVimIM_dbForId(a:dbId)
    if empty(task) || empty(db)
        return
    endif
    if a:exitCode != '0'
        let task['dbMapNew'] = {}
        return
    endif
    if filereadable(task['cachePath'] . '/dbLoadCache_' . a:c)
        call ZFVimIM_DEBUG_profileStart('dbLoadPart')
        let task['dbMapNew'][a:c] = readfile(task['cachePath'] . '/dbLoadCache_' . a:c)
        call ZFVimIM_DEBUG_profileStop()
        if empty(task['dbMapNew'][a:c])
            unlet task['dbMapNew'][a:c]
        endif
    endif
endfunction

function! s:UA_dbSaveFallback(dbId, jobStatus)
    let task = get(s:UA_taskMap, a:dbId, {})
    let db = ZFVimIM_dbForId(a:dbId)
    if empty(task) || empty(db)
        return {
                    \   'output' : 'error',
                    \   'exitCode' : '-1',
                    \ }
    endif
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'saving (fallback)...')

    let dbFile = ZFVimIM_cloud_file(task['cloudOption'], 'dbFile')
    let dbCountFile = ZFVimIM_cloud_file(task['cloudOption'], 'dbCountFile')
    call ZFVimIM_dbSave(db, dbFile, dbCountFile)

    return {
                \   'output' : '',
                \   'exitCode' : '0',
                \ }
endfunction

function! s:UA_dbSaveOnEnter(dbId, jobStatus)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'saving...')

    " log
    let logHead = ZFVimIM_cloud_logInfo(task['cloudOption'])
    let groupJobStatus = ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId'])
    call s:cloudAsyncLog(groupJobStatus, logHead . 'changes:')
    for dbEdit in task['dbEdit']
        call s:cloudAsyncLog(groupJobStatus, logHead . '  ' . printf('%6s', dbEdit['action']) . "\t" . dbEdit['key'] . ' ' . dbEdit['word'])
    endfor

    " prepare to save
    call ZFVimIM_DEBUG_profileStart('dbSaveDBEditWrite')
    call ZFVimIM_cloud_dbEditToFile(task['cloudOption'], task['cachePath'] . '/dbSaveCache', task['dbEdit'])
    call ZFVimIM_DEBUG_profileStop()
endfunction
function! s:UA_dbSaveOnOutput(dbId, jobStatus, textList, type)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    for text in a:textList
        call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'saving: ' . text)
    endfor
endfunction

function! s:UA_dbUploadOnEnter(dbId, jobStatus)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'pushing...')
endfunction
function! s:UA_dbUploadOnOutput(dbId, jobStatus, textList, type)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    for text in a:textList
        call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'pushing : ' . text)
    endfor
endfunction

function! s:UA_dbCleanupCheckOnOutput(dbId, jobStatus, textList, type)
    let task = get(s:UA_taskMap, a:dbId, {})
    let db = ZFVimIM_dbForId(a:dbId)
    if empty(task) || empty(db)
        return
    endif
    for text in a:textList
        let history = substitute(text, '[\r\n]', '', 'g')
        if empty(history)
            continue
        endif
        let history = str2nr(history)
        let db['implData']['_dbCleanupHistory'] = history
        call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'history : ' . history)
    endfor
endfunction
function! s:UA_dbCleanupOnOutput(dbId, jobStatus, textList, type)
    let task = get(s:UA_taskMap, a:dbId, {})
    if empty(task)
        return
    endif
    for text in a:textList
        call s:cloudAsyncLog(ZFGroupJobStatus(a:jobStatus['jobImplData']['groupJobId']), ZFVimIM_cloud_logInfo(task['cloudOption']) . 'cleaning : ' . text)
    endfor
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

        if !empty(task['dbMapNew'])
            let db['dbMap'] = task['dbMapNew']
            call ZFVimIM_dbSearchCacheClear(db)
        endif

        if a:exitCode == '0'
            let db['implData']['_dbLoadRequired'] = 0
            call s:cloudAsyncLog(a:groupJobStatus, ZFVimIM_cloud_logInfo(task['cloudOption']) . 'update success')
            let s:autoUploadAsyncRetryTimeInc = 1
            if !empty(db['dbEdit'])
                call s:autoUploadAsync()
            endif
            break
        endif

        " upload failed, so restore dbEdit
        call extend(db['dbEdit'], task['dbEdit'], 0)

        call s:cloudAsyncLog(a:groupJobStatus, ZFVimIM_cloud_logInfo(task['cloudOption']) . 'update failed, exitCode: ' . a:exitCode . ', detailed log:')
        for output in a:groupJobStatus['jobOutput']
            call s:cloudAsyncLog(a:groupJobStatus, '    ' . output)
        endfor
        call s:cloudAsyncLog(a:groupJobStatus, ZFVimIM_cloud_logInfo(task['cloudOption']) . 'update failed, exitCode: ' . a:exitCode)

        " auto retry if not stopped by user
        if a:exitCode != g:ZFJOBSTOP
            let s:autoUploadAsyncRetryTimeInc = s:autoUploadAsyncRetryTimeInc * 2
            if !empty(db['dbEdit'])
                call s:autoUploadAsync()
            endif
        endif
        break
    endwhile

    " final cleanup
    if !empty(task)
        if isdirectory(task['cachePath'])
            call ZFVimIM_rm(task['cachePath'])
        endif
    endif
    call ZFJobOutputCleanup(a:groupJobStatus)
    call s:UA_lockCleanupJob(a:groupJobStatus)

    if !empty(task) && task['mode'] == 'init' && get(task['cloudOption'], 'mode', '') != 'local'
        call s:uploadAsync(task['cloudOption'], 'download')
    endif
endfunction

" ============================================================
" lock logic
function! s:UA_lockCleanupJob(groupJobStatus)
    let lockAcquired = ZFVimIM_cloud_lockAcquired()
    call ZFVimIM_cloud_lockRelease()
    if !lockAcquired
        return {
                    \   'output' : 'failed: locked by other vim process',
                    \   'exitCode' : 'ZFVimIM_cloud_lockUnavailable',
                    \ }
    else
        return {
                    \   'output' : 'success',
                    \   'exitCode' : '0',
                    \ }
    endif
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
if exists('v:vim_did_enter') && v:vim_did_enter
    call s:UA_autoInit()
endif

