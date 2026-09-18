# px

`px` 是一个命令前缀，让被包裹的**单条命令**通过代理执行，而不改动当前终端会话、系统代理，或 Git/npm 的全局配置。

它适合临时为 `git`、`npm`、`curl`、`pip`、`cargo` 和 `go` 等命令启用本地 HTTP 代理。支持 Windows PowerShell 5.1/7+，以及 Git Bash、WSL、Linux、macOS 上的 bash/zsh。

## 安装

在**要使用的那个终端**里跑一行：

| 终端 | 命令 |
| --- | --- |
| PowerShell 5.1 / 7+ | `irm https://raw.githubusercontent.com/weimasun/px/main/install-remote.ps1 \| iex` |
| Git Bash / WSL / Linux / macOS | `curl -fsSL https://raw.githubusercontent.com/weimasun/px/main/install-remote.sh \| bash` |

它会把脚本下载到 `~/px`，然后把加载语句写进你的 PowerShell profile / shell rc 文件。重跑同一行即升级脚本，`px-proxy.txt`（你的代理地址）不会被覆盖。

每种终端各装各的：PowerShell 只认 profile，Git Bash 和 WSL 各自有自己的 `~/.bashrc`，路径格式也不同（`/c/...` 与 `/mnt/c/...`）。装完重开一个终端生效，或按安装脚本输出的命令手动加载一次。

> [!WARNING]
> `irm <url> | iex` 和 `curl ... | bash` 会直接执行该地址返回的内容。上面两个脚本各只有几十行，先打开 URL 看一眼再跑。

只想临时用一次、不写进 profile 的话，可以只加载函数本身（仅当前窗口有效）：

```powershell
irm https://raw.githubusercontent.com/weimasun/px/main/px.ps1 | iex
```

```sh
source <(curl -fsSL https://raw.githubusercontent.com/weimasun/px/main/px.sh)
```

这种用法下 `px` 仍会读写 `~/px/px-proxy.txt`，与安装版共用同一份配置。

## 设置代理地址

首次需要指定代理地址。把下面的 `127.0.0.1:7890` 换成**你自己的**代理监听地址和端口（例如 Clash 混合端口、v2ray 的 HTTP 入站等）：

```sh
px --set 127.0.0.1:7890
```

地址只保存在 `~/px/px-proxy.txt`，不会进仓库。

## 使用

```sh
px git clone https://github.com/owner/repository.git
px npm install
px curl -sI https://github.com
```

运行不带参数的 `px` 可查看用法和当前代理地址。

### 配置和检查默认代理

```sh
px --set 127.0.0.1:8080
px
px-status
px-status 127.0.0.1:8080
```

不带参数运行 `px` 会打印用法和当前代理地址；没有单独的 `--show`。

没有 `://` 的地址会自动补为 `http://`；命令自身的参数会原样传递。

`--set` 将默认地址保存至 `px-proxy.txt`。`px-status` 会通过该代理向 GitHub 发送请求，检查连通性。

代理地址**只**来自 `px-proxy.txt`：没有环境变量覆盖，也没有硬编码兜底值。文件缺失或为空时，`px` 报错退出并提示 `px --set <addr>`。

## 工作方式

`px <command>` 会为子进程设置标准代理环境变量：

```text
HTTP_PROXY
HTTPS_PROXY
ALL_PROXY
NO_PROXY=localhost,127.0.0.1,::1
```

PowerShell 版本会在命令结束后恢复原有环境变量；bash/zsh 版本使用仅对子进程有效的前缀环境变量。Unix 系统中，大小写两种变量名都会设置，以适配不同工具。

> [!IMPORTANT]
> `px` 仅影响尊重这些环境变量的程序。Git SSH 地址（例如 `git@github.com:owner/repository.git`）不走 HTTP 代理，需要单独配置 SSH 的 `ProxyCommand`。

## 平台说明

- PowerShell 侧会更新 Windows PowerShell 5.1 与 PowerShell 7+ 的 profile。移动 `~/px` 目录后，重跑一次安装命令即可更新路径。
- WSL2 中的 `127.0.0.1` 指向 WSL 虚拟机而非 Windows 宿主机。脚本会将其自动替换为默认网关 IP；若地址不正确，在 shell 配置中设置 `PX_WSL_HOST_IP=<宿主机 IP>`。
- PowerShell 加载 profile 需要允许脚本执行。安装脚本在当前用户的执行策略为 `Undefined` 或 `Restricted` 时，会自动设为 `CurrentUser RemoteSigned`；若你所在环境禁止修改策略，请自行改为其它方式加载脚本。

## 验证

安装完成后，新开一个 PowerShell 窗口并运行：

```powershell
pwsh.exe -File "$HOME\px\verify-px.ps1" -LogPath "$HOME\px\result.txt"
Get-Content "$HOME\px\result.txt"
```

验收脚本会检查 `px` 是否加载、`curl`/`git`/`npm` 的代理调用、参数透传，以及代理环境变量是否正确恢复。

目前只有 PowerShell 侧的自动验收脚本；bash/zsh 侧请手动确认：`px curl -sI https://github.com` 能通，且 `echo $HTTP_PROXY` 在命令结束后为空。

## 卸载

在相同类型的终端中执行对应卸载脚本：

```powershell
pwsh.exe -File "$HOME\px\uninstall-px.ps1"
```

```sh
bash ~/px/uninstall-px.sh
```

卸载脚本只移除 profile 或 shell rc 文件中的 `px` 加载配置，不会删除 `~/px` 目录或 `px-proxy.txt`。想彻底清除的话，手动删掉这个目录：

```sh
rm -rf ~/px
```

## 文件说明

| 文件 | 说明 |
| --- | --- |
| `install-remote.ps1` / `install-remote.sh` | 安装入口，供 `irm ... \| iex` / `curl ... \| bash` 使用 |
| `px.ps1` | PowerShell 实现，定义 `px` 和 `px-status` |
| `px.sh` | bash/zsh 实现，适用于 Git Bash、WSL、Linux 和 macOS |
| `install-px.ps1` / `install-px.sh` | 写入 shell 启动配置，由安装入口调用 |
| `uninstall-px.ps1` / `uninstall-px.sh` | 移除对应 shell 的加载配置 |
| `verify-px.ps1` | PowerShell 侧的验收脚本 |
| `px-proxy.txt` | 可由 `px --set` 更新的默认代理地址（本地生成，不入库） |

## 许可证

MIT，详见 [LICENSE](LICENSE)。
