
<!-- vim-markdown-toc GFM -->

* [introduction](#introduction)
* [how to use](#how-to-use)
* [cloud input](#cloud-input)
    * [cloud input (minimal recommend config)](#cloud-input-minimal-recommend-config)
    * [cloud input (detail config)](#cloud-input-detail-config)
    * [db samples](#db-samples)
* [detailed](#detailed)
    * [configs](#configs)
    * [functions](#functions)
    * [functions (for db repo)](#functions-for-db-repo)
    * [FAQ](#faq)
    * [known issue](#known-issue)

<!-- vim-markdown-toc -->

# introduction

Input Method by pure vim script, inspired by [VimIM](https://github.com/vim-scripts/VimIM)

Outstanding features / why another remake:

* more friendly long sentence match and better predict logic
* predict from multiple db without switching dbs
* auto create user word and re-order word priority accorrding to your input history
* cloud input, auto pull and push your db file from/to Github
* solve many VimIM's issues:
    * better txt db load performance if `has('python')`
    * auto disable and re-enable complete engines when using input method
    * sync input method state acrossing buffers

![](https://raw.githubusercontent.com/ZSaberLv0/ZFVimIM/master/preview.gif)

if you like my work, [check here](https://github.com/ZSaberLv0?utf8=%E2%9C%93&tab=repositories&q=ZFVim) for a list of my vim plugins


# how to use

1. requirement:

    * `v:version >= 704`, older version may work, but not tested
    * (optional) `git`, for db update
    * (optional) `vim8` with `job` or `neovim`, and `Plug 'ZSaberLv0/ZFVimJob'`, for async db update
    * (optional) `has('python')` or `has('python3')`, for better db load performance

1. use [Vundle](https://github.com/VundleVim/Vundle.vim) or any other plugin manager you like to install

    ```
    Plugin 'ZSaberLv0/ZFVimIM'
    Plugin 'YourUserName/YourDbRepo' " repo that contain db files, see `cloud input (minimal recommend config)`

    Plugin 'ZSaberLv0/ZFVimJob' " optional, for async db update
    Plugin 'ZSaberLv0/ZFVimGitUtil' " optional, see `g:ZFVimIM_cloudAsync_autoCleanup`
    ```

1. use `;;` to toggle input method

    default keymaps:

    ```
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
    ```

    you may disable default keymap by `let g:ZFVimIM_keymap = 0`

1. during input:

    * scroll page by `-` or `=`
    * input and choose word by `<space>` or `0~9`
    * choose head or tail word by `[` or `]`

1. your input history would be recorded and
    automatically push to github,
    see `cloud input` below for more info


# cloud input

## cloud input (minimal recommend config)

1. fork [ZSaberLv0/ZFVimIM_pinyin_base](https://github.com/ZSaberLv0/ZFVimIM_pinyin_base)
    to `Plugin 'YourUserName/ZFVimIM_pinyin_base'`

    ```
    Plugin 'ZSaberLv0/ZFVimIM'
    Plugin 'YourUserName/ZFVimIM_pinyin_base'
    Plugin 'ZSaberLv0/ZFVimJob'
    Plugin 'ZSaberLv0/ZFVimGitUtil'
    ```

1. supply your git info (make sure it has `git push` [permission](https://github.com/settings/tokens))

    ```
    let g:ZFVimIM_pinyin_gitUserEmail='YourEmail'
    let g:ZFVimIM_pinyin_gitUserName='YourUserName'
    let g:ZFVimIM_pinyin_gitUserToken='YourGithubAccessToken'
    ```

## cloud input (detail config)

once configured properly, your db changes would be pushed to Github automatically

requirement:

* register and supply your db repo and git info, see also:
    * [ZSaberLv0/ZFVimIM_pinyin_base](https://github.com/ZSaberLv0/ZFVimIM_pinyin_base)
    * [functions (for db repo)](#functions-for-db-repo)
* (optional) have [ZSaberLv0/ZFVimJob](https://github.com/ZSaberLv0/ZFVimJob) installed and `ZFJobAvailable()`,
    for async pull and push
* (optional) have `has('python')` or `has('python3')` support for better save/load performance


if it's hard to support async mode, you may also:

* pull and push manually by `:call ZFVimIM_download()` and `:call ZFVimIM_upload()`
* automatically ask you to input git info to push before exit vim,
    by `let g:ZFVimIM_cloudSync_enable=1`


of course, you must have push permission for db repo,
feel free to fork the default repo (`ZSaberLv0/ZFVimIM_pinyin_base`),
or supply your own db repo


**NOTE:**

since db files are pretty personal,
the default db only contains single word,
words would be created during your usage

if you prefer other choices, see [db samples](https://github.com/ZSaberLv0/ZFVimIM#db-samples):


**NOTE:**

your db repo may contain many commits after long time usage,
which may cause a huge `.git` dir,
it's recommended to clean up it occasionally, by:

* delete and re-create the repo
* if you have `push --force` permission,
    use [ZSaberLv0/ZFVimGitUtil](https://github.com/ZSaberLv0/ZFVimGitUtil)'s
    `:ZFGitHardRemoveAllHistory` to remove all history commits,
    or use `g:ZFVimIM_cloudAsync_autoCleanup` for short


## db samples

* [ZSaberLv0/ZFVimIM_pinyin](https://github.com/ZSaberLv0/ZFVimIM_pinyin) :
    pinyin repo which I personally used,
    update frequently
* [ZSaberLv0/ZFVimIM_pinyin_base](https://github.com/ZSaberLv0/ZFVimIM_pinyin_base) :
    base pinyin repo that only contain single word,
    recommended if you care about performance
    or want to create personal user word during usage
* [ZSaberLv0/ZFVimIM_pinyin_huge](https://github.com/ZSaberLv0/ZFVimIM_pinyin_huge) :
    huge pinyin repo that contains many words,
    it's converted from other IME and haven't been daily used,
    which may contain many useless words,
    I put it here just in case you prefer huge db or want to test huge db's performance
* [ZSaberLv0/ZFVimIM_wubi_base](https://github.com/ZSaberLv0/ZFVimIM_wubi_base) :
    wubi converted from [ywvim](https://github.com/vim-scripts/ywvim)


# detailed

## configs

* `let g:ZFVimIM_autoAddWordLen=3*4`

    when you choose word and the word's byte length less than this value,
    we would add the word to db file automatically
    (ignored when `g:ZFVimIM_autoAddWordChecker` is set)

* `let g:ZFVimIM_autoAddWordChecker=[]`

    list of function to check whether need to add user word

    ```
    function! MyChecker(userWord)
        let needAdd = ...
        return needAdd
    endfunction
    let g:ZFVimIM_autoAddWordChecker=[function('MyChecker')]
    ```

    when any of checker returned `0`, we won't add user word

* `let g:ZFVimIM_symbolMap = {}`

    used to transform unicode symbols during input

    it's empty by default, typical config for Chinese:

    ```
    let g:ZFVimIM_symbolMap = {
                \   ' ' : [''],
                \   '`' : ['·'],
                \   '!' : ['！'],
                \   '$' : ['￥'],
                \   '^' : ['……'],
                \   '-' : [''],
                \   '_' : ['——'],
                \   '(' : ['（'],
                \   ')' : ['）'],
                \   '[' : ['【'],
                \   ']' : ['】'],
                \   '<' : ['《'],
                \   '>' : ['》'],
                \   '\' : ['、'],
                \   '/' : ['、'],
                \   ';' : ['；'],
                \   ':' : ['：'],
                \   ',' : ['，'],
                \   '.' : ['。'],
                \   '?' : ['？'],
                \   "'" : ['‘', '’'],
                \   '"' : ['“', '”'],
                \   '0' : [''],
                \   '1' : [''],
                \   '2' : [''],
                \   '3' : [''],
                \   '4' : [''],
                \   '5' : [''],
                \   '6' : [''],
                \   '7' : [''],
                \   '8' : [''],
                \   '9' : [''],
                \ }
    ```

    note, if you want to change this setting at runtime,
    you should use `call ZFVimIME_stop() | call ZFVimIME_start()`
    to restart to take effect

* `let g:ZFVimIM_cachePath=$HOME.'/.vim_cache'`

    cache path for temp files

* `let g:ZFVimIM_cloudAsync_outputTo={...}`

    for async cloud input, output log to where
    (see [ZFJobOutput](https://github.com/ZSaberLv0/ZFVimJob)), default:

    ```
    let g:ZFVimIM_cloudAsync_outputTo = {
                \   'outputType' : 'statusline',
                \   'outputId' : 'ZFVimIM_cloud_async',
                \ }
    ```

* `let g:ZFVimIM_cloudAsync_autoCleanup=30`

    for async cloud input only,
    we would try to remove all history commits if:

    * `g:ZFVimIM_cloudAsync_autoCleanup` greater than 0
    * your `git rev-list --count HEAD` exceeds `g:ZFVimIM_cloudAsync_autoCleanup`
    * have [ZSaberLv0/ZFVimGitUtil](https://github.com/ZSaberLv0/ZFVimGitUtil) installed

    NOTE:

    * this require you have `git push --force` permission,
        if not, please disable this feature,
        otherwise your commits may lost occasionally
        (each time when commits exceeds `g:ZFVimIM_cloudAsync_autoCleanup`)

* `let g:ZFVimIM_cloudAsync_autoInit=1`

    for async cloud input only,
    when on, we would load db when `VimEnter`,
    to reduce the time you first `ZFVimIME_start()`


## functions

* `ZFVimIME_start()` `ZFVimIME_stop()` `ZFVimIME_toggle()` `ZFVimIME_next()`

    start or stop, must called during Insert Mode, as
    `<c-r>=ZFVimIME_start()<cr>`

* `:IMAdd word key` or `ZFVimIM_wordAdd(word, key)`

    manually add word

* `:IMRemove word [key]` or `ZFVimIM_wordRemove(word [, key])`

    manually remove word

* `:IMReorder word [key]` or `ZFVimIM_wordReorder(word [, key])`

    manually reorder word priority,
    by reducing it's input history count to a proper value

* `ZFVimIM_complete(key [, option, db])`

    * option

        ```
        {
          'sentence' : '0/1',
          'crossDb' : 'maxNum, default to g:ZFVimIM_crossDbLimit',
          'predict' : 'maxNum, default to g:ZFVimIM_predictLimit',
          'match' : 'maxNum, default to -1',
        }
        ```

    * return

        ```
        [
          {
            'dbId' : 'match from which db',
            'len' : 'match count in key',
            'key' : 'matched full key',
            'word' : 'matched word',
            'type' : 'type of completion: sentence/match/predict',
            'sentenceList' : [ // for sentence type only, list of word that complete as sentence
              {
                'key' : '',
                'word' : '',
              },
            ],
          },
          ...
        ]
        ```

    note, you may supply your own function named `ZFVimIM_complete`
    to override the default one,
    and use `ZFVimIM_completeDefault(key, option, db)` to achieve custom IME complete


## functions (for db repo)

* `ZFVimIM_dbInit(option)`

    to register a db, option:

    ```
    {
      'name' : 'name of your db',
      'priority' : '100 by default, smaller value means higher priority',
      'implData' : { // extra data for impl
      },
    }
    ```

    return db object which would stored in `g:ZFVimIM_db`

* `ZFVimIM_cloudRegister(cloudOption [, sync/async])`

    register cloud info, when registered,
    we would try to pull/push from/to remote repo

    cloudOption:

    ```
    {
      'repoPath' : 'git repo path',
      'dbFile' : 'db file path relative to repoPath, must start with /',
      'dbCountFile' : 'optional, db count file path relative to repoPath, must start with /',
      'gitUserEmail' : 'git user email',
      'gitUserName' : 'git user name',
      'gitUserToken' : 'git access token or password',
      'dbId' : 'dbId generated by ZFVimIM_dbInit()'
    }
    ```


## FAQ

* Q: How to use in `Command-line` (search or command) ?

    A: ZFVimIM can be used inside `command-line-window`, you may:

    * (in normal mode) use `q:` or `q/` to enter `command-line-window`
    * (when entering command) use these keymaps:

        ```
        function! ZF_Setting_cmdEdit()
            let cmdtype = getcmdtype()
            if cmdtype != ':' && cmdtype != '/'
                return ''
            endif
            call feedkeys("\<c-c>q" . cmdtype . 'k0' . (getcmdpos() - 1) . 'li', 'nt')
            return ''
        endfunction
        cnoremap <silent><expr> ;; ZF_Setting_cmdEdit()
        ```

* Q: strange complete popup?

    A: we use `omnifunc` to achieve IM popup,
    which would conflict with most of complete engines,
    by default, we would automatically disable complete engines when IM started,
    if your other plugins conflict with IM,
    you may disable it manually
    ([see this](https://github.com/ZSaberLv0/ZFVimIM/blob/master/plugin/ZFVimIM_autoDisable.vim))

    also, if any strange behaviors occurred,
    `:verbose set omnifunc?` to check whether it's changed by other plugins


## known issue

* too slow

    if your db file is very large,
    it's slow to save and load db even if `has('python')`,
    because db data are passed as json format between vim and python,
    it's slow to perform `json_encode`

    this plugin is designed lightweight that can fallback to pure vimscript,
    so, there's no plan to completely move db data to python side
    (further more, async complete popup would break `:lmap` logic,
    and require features like LSP plugins,
    no plan to achieve this too)

    if you want to benchmark:

    1. `let g:ZFVimIM_DEBUG_profile = 1`
    1. input freely
    1. `call ZFVimIM_DEBUG_profileInfo()` to check which step consumed most time

* use with LSP plugins

    it's possible,
    but it's a better design to make a external executable for LSP plugins,
    not some vimscript like this plugin,
    so, no plan on this

    if you really want to hack, there's two idea:

    * use `ZFVimIM_complete()` to get word completion,
        and supply things like `omnifunc` for LSP plugins
    * use python or other tools to parse db files and supply LSP plugins

* can not use in `input()`

    unfortunately, I've no idea how to make `lmap` work in `input()`,
    and there's no plan to make complex `cmap` to achieve this

    of course, if you have better solution, PR is always welcomed

