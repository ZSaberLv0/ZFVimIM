
<!-- vim-markdown-toc GFM -->

* [简介](#简介)
* [推荐配置](#推荐配置)
    * [纯本地词库](#纯本地词库)
    * [云词库](#云词库)
* [使用](#使用)
* [一些使用技巧](#一些使用技巧)
* [疑难杂症](#疑难杂症)

<!-- vim-markdown-toc -->

# 简介

vim 上的输入法, 特色:

* 支持自动 pull/push 词库到 gayhub 哦不 github
* 支持异步调用外部云输入法 (目前支持百度输入法)
* 动态组词, 动态词频, 长句输入
* 支持挂各种大词库, 支持多词库混输, 中英日甚至颜文字都行, 只要能按格式提供词库
* 辣鸡环境可以回退到纯 vim script 版本, 最低支持 vim 7.3,
    当然也支持无网络纯本地使用


(防杠补丁) Why not 系统输入法:

* vim 的一大优势就是 ssh 到处都能用, 至少大多数 ssh 环境用系统输入法都很蛋疼
* `inoremap jk <esc>` 流派的福音


词库同步及长句输入:

![](https://raw.githubusercontent.com/ZSaberLv0/ZFVimIM/master/preview.gif)


多词库混输: (不卡, gif 图的问题, 懒得重新搞了 `(- -b)`)

![](https://raw.githubusercontent.com/ZSaberLv0/ZFVimIM/master/preview_crossdb.gif)


如果你喜欢本插件, 给开发者[买个煎饼补补脑](https://github.com/ZSaberLv0/ZSaberLv0),
或者看看其它[好玩的插件](https://github.com/ZSaberLv0?utf8=%E2%9C%93&tab=repositories&q=ZFVim)


# 推荐配置

* 中文帮助只列举推荐配置和基本操作 (足够日常使用),
    详细配置等请移步 [README](https://github.com/ZSaberLv0/ZFVimIM/blob/master/README.CN.md)
    (别问为啥, 问就是懒)
* 如果你也是个懒人, 只想先快速体验一下,
    可以先试试[纯本地词库](https://github.com/ZSaberLv0/ZFVimIM/blob/master/README.CN.md#%E7%BA%AF%E6%9C%AC%E5%9C%B0%E8%AF%8D%E5%BA%93),
    当然个人建议还是: 轻量词库 + 自造词 + 百度云输入,
    按照下文推荐配置花点时间即可实现


## 纯本地词库

虽然重点功能之一是自动同步词库, 但纯本地跑也是可以的

1. 推荐环境:

    * (可选) vim8 或 neovim, 用于提升词库加载性能
    * (可选) `executable('python')` 或者 `executable('python3')`, 用于提升词库加载性能

1. 推荐安装

    ```
    Plugin 'ZSaberLv0/ZFVimIM'
    Plugin 'ZSaberLv0/ZFVimJob' " 可选, 用于提升词库加载性能
    ```

1. 准备你的词库文件,
    也可以从 [db samples](https://github.com/ZSaberLv0/ZFVimIM#db-samples)
    中把 txt 词库文件复制到任意目录
1. 配置

    ```
    function! s:myLocalDb()
        let db = ZFVimIM_dbInit({
                    \   'name' : 'YourDb',
                    \ })
        call ZFVimIM_cloudRegister({
                    \   'mode' : 'local',
                    \   'dbId' : db['dbId'],
                    \   'repoPath' : '/path/to/repo', " 词库路径
                    \   'dbFile' : '/YourDbFile', " 词库文件, 相对 repoPath 的路径
                    \   'dbCountFile' : '/YourDbCountFile', " 非必须, 词频文件, 相对 repoPath 的路径
                    \ })
    endfunction
    if exists('*ZFVimIME_initFlag') && ZFVimIME_initFlag()
        call s:myLocalDb()
    else
        autocmd User ZFVimIM_event_OnDbInit call s:myLocalDb()
    endif
    ```


## 云词库

1. 推荐环境:

    * (可选) vim8 或 neovim, 用于提升词库加载性能
    * (可选) `executable('python')` 或者 `executable('python3')`, 用于提升词库加载性能

1. 参照 [db samples](https://github.com/ZSaberLv0/ZFVimIM#db-samples) 创建自己的词库,
    或 fork 以下词库:

    * 拼音 (单字词库): [ZSaberLv0/ZFVimIM_pinyin_base](https://github.com/ZSaberLv0/ZFVimIM_pinyin_base)
        : 仅包含单字, 无词组, 由于词库和个人使用有关, 本插件的自动组词算法毕竟比不上专业的输入法,
        用大词库容易一堆废词, 因此比较建议从单字词库慢慢组词使用
    * 拼音 (大词库): [ZSaberLv0/ZFVimIM_pinyin_huge](https://github.com/ZSaberLv0/ZFVimIM_pinyin_huge)
        : 大词库, 可能包含一堆废词, 主要丢这边给各位测测使用体验和性能
    * 拼音: [ZSaberLv0/ZFVimIM_pinyin](https://github.com/ZSaberLv0/ZFVimIM_pinyin)
        : 个人在用词库, 时不时 `git push --force`
    * 五笔: [ZSaberLv0/ZFVimIM_wubi_base](https://github.com/ZSaberLv0/ZFVimIM_wubi_base)
        : [ywvim](https://github.com/vim-scripts/ywvim) 转换来的词库, 我对五笔不熟, 各位自行尝试
    * 英语: [ZSaberLv0/ZFVimIM_english_base](https://github.com/ZSaberLv0/ZFVimIM_english_base)
        : 一些基本的英语单词
    * 日语: [ZSaberLv0/ZFVimIM_japanese_base](https://github.com/ZSaberLv0/ZFVimIM_japanese_base)
        : 一些基本的日语单词

1. 到 [access tokens](https://github.com/settings/tokens) 配置一个合适的 token,
    并确保对词库 repo 有 push 权限 (`Select scopes` 中勾选 `repo`)
1. 根据你的词库, 配置相应的 access token, 例如上述词库可以用:

    ```
    let g:zf_git_user_email='YourEmail'
    let g:zf_git_user_name='YourUserName'
    let g:zf_git_user_token='YourGithubAccessToken'
    ```

    具体请查看词库的说明或源码

1. 安装:

    ```
    Plugin 'ZSaberLv0/ZFVimIM'
    Plugin 'ZSaberLv0/ZFVimJob' " 可选, 用于提升词库加载性能
    Plugin 'ZSaberLv0/ZFVimGitUtil' " 可选, 如果你希望定期自动清理词库 push 历史
    Plugin 'YourUserName/ZFVimIM_pinyin_base' " 你的词库
    Plugin 'ZSaberLv0/ZFVimIM_openapi' " 可选, 百度云输入法

    " 国内辣鸡网络, 可以尝试用这个镜像, 与 github 直接互通
    " 或者干脆用 gitee 等国内站点
    Plugin 'https://hub.fastgit.xyz/YourUserName/ZFVimIM_pinyin_base' " 你的词库
    ```


# 使用

* `;;` 开启或关闭输入法, `;:` 切换词库
* `-` 和 `=` 翻页
* `空格` 和 `0~9` 选词或组词
* `[` 和 `]` 快速从词组选字
* 输入过程中会自动组自造词, 也可以用 `;,` 或 `:IMAdd` 手动添加自造词,
    `;.` 或 `:IMRemove` 删除自造词
* 觉得好用, 记得给开发者[买个煎饼](https://github.com/ZSaberLv0/ZSaberLv0),
    贫穷码农在线乞讨 `_(:з」∠)_`


# 一些使用技巧

* 可以在 `:h 'statusline'` 展示当前 IME 状态

    ```
    let &statusline='%{ZFVimIME_IMEStatusline()}'.&statusline
    ```

* 命令行和搜索中没法直接使用, 可以利用 `:h command-line-window`

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

    用法: 在命令行输入过程中, 按 `;;` 进入 `command-line-window`, 在这里面可以用本插件进行输入

* `:terminal` 中没法使用, 也可以利用 `:h command-line-window`

    ```
    if has('terminal') || has('nvim')
        function! PassToTerm(text)
            let @t = a:text
            if has('nvim')
                call feedkeys('"tpa', 'nt')
            else
                call feedkeys("a\<c-w>\"t", 'nt')
            endif
            redraw!
        endfunction
        command! -nargs=* PassToTerm :call PassToTerm(<q-args>)
        tnoremap ;; <c-\><c-n>q:a:PassToTerm<space>
    endif
    ```

    用法: 在 `:terminal` window 的 `Insert-mode` 下, 按 `;;` 进入 `command-line-window` 用本插件进行输入


# 疑难杂症

* 卡顿/加载慢? 请先检查 `call ZFVimIM_DEBUG_checkHealth()`,
    需要 `ZFJobAvailable: 1` 以及 `python: 1`

    * 1M 左右的词库正常配置的话应该几秒内能加载完成
    * 10M 左右的大词库大约需要 5~30秒
    * Windows 或 Cygwin 上相比于 Linux/Mac 可能会尤其慢, 建议排查:
        * 看看是否有 360 等杀毒软件, 词库加载涉及很多 job 多线程操作,
            杀毒软件可能每次都会扫描引起严重拖慢, 亲测加信任也无效
        * 检查 `PATH` 是否有过多内容

* 发现各种诡异现象, 请先按如下步骤排查:

    1. 本插件依赖于 `lmap` 和 `omnifunc`,
        `verbose set omnifunc?` 查看是否被其它插件修改了
    1. 本插件没法和大多数补全插件共存,
        默认会 [自动禁用和恢复](https://github.com/ZSaberLv0/ZFVimIM/blob/master/plugin/ZFVimIM_autoDisable.vim)
        一些常见的补全插件,
        如果你用的补全插件不在此列,
        请先参照进行自动禁用和恢复, 看看是否有效果

