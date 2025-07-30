# pwshrc
[中文](README.zh.md)

> Seamlessly migrate your `.bashrc` configuration to PowerShell!

**pwshrc** is a lightweight PowerShell script that loads and parses Linux-style `.bashrc` files, automatically applying the configurations to the current PowerShell session. It's perfect for developers transitioning from Linux/Bash environments to Windows.

## Key Features

- **Supports parsing only content within `#PS ... #SP` blocks**  
  Only processes the sections you specify, avoiding accidental parsing of irrelevant scripts.

- **Supports `export VAR=value` for setting environment variables**  
  Automatically converts `$VAR` to PowerShell's `$env:VAR`, and expands its value.

- **Supports `alias name='cmd'` for creating aliases or functions**  
  Simple aliases use `Set-Alias`; complex commands are converted into PowerShell functions.

- **Supports command substitution syntax: `$(...)` → `$(& ...)`**  
  Subcommands used in aliases or variables will work correctly.

- **Supports `source ~/.bash_profile` or `. ~/.bash_aliases`**  
  Recursively loads other configuration files, preserving modular structure.

- **Automatically recognizes Unix paths `/c/Users/xxx` → `C:\Users\xxx`**

- **Simulates Bash built-in variables (e.g., `$HOME`, `$USER`, `$HOSTNAME`)**  
  Even if not natively supported in PowerShell, it can parse them as written in `.bashrc`.

- **Supports batch creation of corresponding PowerShell functions for shell scripts**  
  Runs shell scripts using BusyBox bash, with support for argument passing.

- **Supports bulk sourcing similar to profile.d directories**

---

## Usage

### 1. Installation

* Using Scoop
    ```powershell
    scoop install https://raw.githubusercontent.com/k88936/pwshrc/refs/heads/main/pwshrc.json
    ```

* Manual Installation
    ```powershell
    git clone https://github.com/k88936/pwshrc.git
    cd pwshrc
    ./install.ps1
    # Use uninstall.ps1 to uninstall
    # ./uninstall.ps1
    ```

### 2. Edit `.bashrc`
You can write your `.bashrc` just like in Bash, but only the content within the `#PS ... #SP` block will be loaded:

```bash
#PS
export PATH="$PATH:/usr/bin"
alias ll="ls -la"
alias code="/c/Program Files/Code.exe"
alias cdf="cd \"\$(fzf --walker=follow,dir,hidden)\""
source ~/.bash_aliases
#SP
```

#### Advanced Features

* **Add standalone shell scripts as PowerShell functions**
  ```bash
  #PS
  export USER_BIN_PATH=$HOME/.configure/bin
  #SP
  # In Bash, we usually add the directory containing custom scripts to the PATH variable,
  # but this doesn't work directly on Windows.
  # Instead, set USER_BIN_PATH to point to your script directory.
  export PATH=$USER_BIN_PATH:$PATH
  ```

* **Execute initialization scripts in profile.d-like directories**
  ```bash
  #PS
  export USER_PROFILE_D_PATH=$HOME/.configure/profile.d
  #SP
  # Since complex logic like loops isn't supported, set USER_PROFILE_D_PATH to the script directory.
  for env in $USER_PROFILE_D_PATH; do
    if [ -f "$env" ]; then
        source "$env"
    fi
  done
  ```

---

## Implementation Overview

- Uses a state machine to detect whether inside the `#PS ... #SP` block.
- Each line is matched using regex to identify `export`, `alias`, `source`, `$()` etc.
- A unified function `ProcessString` handles string processing:
  - Removes quotes
  - Replaces variables `$VAR` → `%VAR%` and expands their values
  - Supports `~` expansion to `$env:USERPROFILE`
  - Converts Unix paths `/c/...` → `C:\...`
  - Supports nested `source` and `. filename`
- All operations maintain PowerShell semantics, no one-time conversion to `.ps1` files.

---

## Limitations and Notes

| Limitation                                   | Description                                                               |
| -------------------------------------------- | ------------------------------------------------------------------------- |
| Does not support all Bash features           | Control structures like `if`, `for`, `while`, `case` will not be executed |
| Not fully compatible with Shell script logic | Only suitable for configuration statements (variables, aliases, etc.)     |

---