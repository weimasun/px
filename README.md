# px

命令前缀：让**单条命令**走代理，不改当前终端、系统代理，也不改 git/npm 的全局配置。

- 支持 Windows PowerShell 5.1/7+、Git Bash、WSL、Linux、macOS 的 bash/zsh
- 支持 git、npm、pip、curl 等遵循代理环境变量的命令

## 试用

只对当前终端生效，不写任何配置。

**PowerShell**

```powershell
irm https://raw.githubusercontent.com/weimasun/px/main/src/px.ps1 | iex
```

**bash / zsh**

```sh
source <(curl -fsSL https://raw.githubusercontent.com/weimasun/px/main/src/px.sh)
```

设置代理地址：

```sh
px --set 127.0.0.1:7890   # 换成你自己的端口，只存 ~/px/px-proxy.txt，地址没写 `://` 会自动补 `http://`
```

试用只在 `~/px` 留下代理地址文件，删掉即可：

```sh
rm -rf ~/px
```

## 安装

在要用的终端里各跑一行，写入配置。

**PowerShell**

```powershell
irm https://raw.githubusercontent.com/weimasun/px/main/src/install-remote.ps1 | iex
```

**bash / zsh**

```sh
curl -fsSL https://raw.githubusercontent.com/weimasun/px/main/src/install-remote.sh | bash
```

脚本下载到 `~/px`，并往对应终端的 profile / rc 里加一行加载语句，重开终端生效。重跑同一行即升级，代理地址不会被覆盖。

设置代理地址：

```sh
px --set 127.0.0.1:7890   # 换成你自己的端口，只存 ~/px/px-proxy.txt，地址没写 `://` 会自动补 `http://`
```

## 其他用法

```sh
px                        # 打印用法和当前代理
px-status                 # 测连通性，也可 px-status <addr> 临时测别的地址
px <command> [args...]    # 让这条命令走代理
```

## 工作原理

`px` 给子进程设 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY` 和 `NO_PROXY=localhost,127.0.0.1,::1`，命令结束后恢复（bash 侧只对子进程生效）。只影响认这些环境变量的程序，Git 的 SSH 地址不走 HTTP 代理。

## 卸载

**PowerShell**

```powershell
& "$HOME\px\uninstall-px.ps1"                # 移除加载语句
Remove-Item -Recurse -Force "$HOME\px"       # 删除缓存文件
```

**bash / zsh**

```sh
bash ~/px/uninstall-px.sh                    # 移除加载语句
rm -rf ~/px                                  # 删除缓存文件
```
