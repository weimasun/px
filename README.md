# px

命令前缀：让**单条命令**走代理，不改当前终端、系统代理，也不改 git/npm 的全局配置。

支持 Windows PowerShell 5.1/7+、Git Bash、WSL、Linux、macOS 的 bash/zsh。

## 安装

在要用的终端里跑一行：

| 终端 | 命令 |
| --- | --- |
| PowerShell | `irm https://raw.githubusercontent.com/weimasun/px/main/src/install-remote.ps1 \| iex` |
| bash / zsh | `curl -fsSL https://raw.githubusercontent.com/weimasun/px/main/src/install-remote.sh \| bash` |

脚本下载到 `~/px`，并在 profile / shell rc 里加一行加载语句，重开终端生效。重跑同一行即升级，代理地址不会被覆盖。每种终端各装各的：PowerShell 写 profile，Git Bash 和 WSL 各写自己的 `~/.bashrc`。

> [!WARNING]
> 这两条命令会直接执行远端返回的脚本内容，先打开 URL 看一眼再跑。

## 用法

```sh
px --set 127.0.0.1:7890   # 设置代理地址，换成你自己的，只存 ~/px/px-proxy.txt
px                        # 打印用法和当前代理
px git clone https://github.com/owner/repo.git
px npm install
px-status                 # 测连通性，也可 px-status <addr> 临时测别的地址
```

- 地址没写 `://` 会自动补 `http://`
- 只认 `px-proxy.txt` 一个来源：没有环境变量覆盖，也没有兜底值，没设置就报错
- 命令自身的参数原样透传
- 自检：`pwsh.exe -File "$HOME\px\verify-px.ps1" -LogPath "$HOME\px\result.txt"`（仅 PowerShell 侧）

## 工作方式

`px` 给子进程设 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY` 和 `NO_PROXY=localhost,127.0.0.1,::1`，命令结束后恢复（bash 侧只对子进程生效）。只影响认这些环境变量的程序，Git 的 SSH 地址不走 HTTP 代理。

WSL2 里 `127.0.0.1` 是虚拟机自身，脚本会自动换成宿主机网关 IP；不对的话设 `PX_WSL_HOST_IP=<宿主机 IP>`。

## 卸载

```sh
pwsh.exe -File "$HOME\px\uninstall-px.ps1"   # PowerShell
bash ~/px/uninstall-px.sh                    # bash / zsh
rm -rf ~/px                                  # 可选：连脚本一起删
```

## 许可证

MIT，详见 [LICENSE](LICENSE)。
