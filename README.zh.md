# pwshrc

> 将你的 `.bashrc` 配置无缝迁移到 PowerShell！

**pwshrc** 是一个轻量级 PowerShell 脚本，用于加载并解析 Linux 风格的 `.bashrc` 文件，并将其配置自动应用到当前 PowerShell 会话中。非常适合从 Linux/Bash 环境迁移到 Windows 的开发者。

## feature

- **支持只解析 `#PS ... #SP` 区块内的内容**  
  只处理你指定的部分，避免误解析无关脚本。

- **支持 `export VAR=value` 设置环境变量**  
  自动将 `$VAR` 替换为 PowerShell 的 `$env:VAR`，并展开实际值。

- **支持 `alias name='cmd'` 创建别名或函数**  
  简单别名用 `Set-Alias`，复杂命令自动转为 PowerShell 函数。

- **支持命令替换语法：`$(...)` → `$(& ...)`**  
  在 alias 或变量中使用子命令也能正常运行。

- **支持 `source ~/.bash_profile` 或 `. ~/.bash_aliases`**  
  递归加载其他配置文件，保持模块化结构。

- **自动识别 Unix 路径 `/c/Users/xxx` → `C:\Users\xxx`**

- **模拟 Bash 内建变量（如 `$HOME`, `$USER`, `$HOSTNAME`）**  
  即使在 PowerShell 中没有原生支持，也能顺利解析 `.bashrc` 中的写法。

- **支持为shell脚本批量创建对应powershell函数**
  利用busybox bash 运行shell脚本,支持参数传递

- **支持对类似profile.d批量执行source**

---

## usage

### 1. 安装
* 使用 Scoop
    ```powershell
    scoop install https://github.com/k88936/scoop-bucket/raw/refs/heads/master/bucket/pwshrc.json 
    ```
* 手动安装
    ``` powershell
    git clone https://github.com/k88936/pwshrc.git
    cd pwshrc
    ./install.ps1
    # # use uninstall.ps1 to uninstall
    # ./uninstall.ps1
    ```

### 2. 编辑 `.bashrc`
你可以像在 Bash 中一样编写 `.bashrc`，但只放在 `#PS ... #SP` 区域内才会被加载：
```bash
#PS
export PATH="$PATH:/usr/bin"
alias ll="ls -la"
alias code="/c/Program Files/Code.exe"
alias cdf="cd \"\$(fzf --walker=follow,dir,hidden)\""
source ~/.bash_aliases
#SP
```
#### 高级特性
* 把独立shell脚本批量添加到函数
  ```bash
  #PS
  export USER_BIN_PATH=$HOME/.configure/bin
  #SP
  # 在bash里,我们通常把自定义的脚本存放的目录添加到PATH变量里, 
  # 但是在windows下并不能用来执行,
  # 实现方法是把 USER_BIN_PATH 变量设为存放脚本的目录路径
  export PATH=$USER_BIN_PATH:$PATH
  ```
* 批量执行profile.d里的初始化
  ```bash
  #PS
  export USER_PROFILE_D_PATH=$HOME/.configure/profile.d
  #SP
  # 由于不支持循环判断复杂逻辑, 可以设 USER_PROFILE_D_PATH 为存放脚本的目录
  for env in $USER_PROFILE_D_PATH; do
    if [ -f "$env" ]; then
          source "$env"
    fi
  done
  ```

---

## 实现原理简述

- 使用状态机判断是否进入 `#PS ... #SP` 区块。
- 对每一行进行正则匹配，识别 `export`, `alias`, `source`, `$()` 等语法。
- 使用统一函数 `ProcessString` 处理字符串：
  - 去除引号
  - 替换变量 `$VAR` → `%VAR%` 并展开值
  - 支持 `~` 展开为 `$env:USERPROFILE`
  - Unix 路径 `/c/...` → `C:/...`
  - 支持嵌套 `source` 和 `. filename`
- 所有操作都保留 PowerShell 的语义，不依赖一次性转换 `.ps1` 文件。

---

## limitation

| 限制                      | 说明                                                 |
| ------------------------- | ---------------------------------------------------- |
| 不支持所有 Bash 特性      | 如 `if`, `for`, `while`, `case` 等控制流语句不会执行 |
| 不完全兼容 Shell 脚本逻辑 | 仅适用于配置类语句（变量、别名等）                   |

---