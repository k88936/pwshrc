Set-PSDebug -Trace 0
$DebugPreference = "Ignore"
# $DebugPreference ="Continue"
Set-PSReadLineKeyHandler -Key Tab -Function Complete
Remove-Item alias:rm
Remove-Item alias:ls
# Remove-Item alias:curl 
New-Alias -Name sudo -Value "$env:USERPROFILE\scoop\apps\sudo\current\sudo.ps1"





function Unescape-BashString {
    param(
        [string]$Value
    )
    Write-Debug "[Unescape-BashString] Input: $Value"

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }

    # Step 1: Replace common escape characters
    $Value = $Value -replace '\\"', '"'           # \" → "
    $Value = $Value -replace '\\\$', '$'          # \$ → $
    $Value = $Value -replace '\\\\', '\'          # \\ → \
    $Value = $Value -replace '\\n', "`n"          # \n → NewLine
    $Value = $Value -replace '\\t', "`t"          # \t → Tab
    $Value = $Value -replace '\\r', "`r"          # \r → Carriage Return

    Write-Debug "[Unescape-BashString] Output: $Value"
    return $Value
}
function Convert-BashCommandSubstitution {
    param(
        [string]$Value
    )
    Write-Debug "[Convert-BashCommandSubstitution] Input: $Value"

    # $(cmd) → $($cmd)
    $Value = $Value -replace '\$\(([^)]+)\)', '$(&$1)'

    Write-Debug "[Convert-BashCommandSubstitution] Output: $Value"
    return $Value
}
function RemoveQuotes {
    param(
        [string]$Value
    )
    Write-Debug "[RemoveQuotes] Input: $Value"
    $Value = $Value -replace '^''(.*)''$', '$1' -replace '^"(.*)"$', '$1'
    Write-Debug "[RemoveQuotes] Output: $Value"
    return $Value
}

function Expand-BashVariable {
    param(
        [string]$Value
    )
    Write-Debug "[Expand-BashVariable] Input: $Value"
    # Step 1: Bash variable format $VAR → Windows format %VAR%
    $converted = $Value -replace '\$(\w+)', '%$1%'

    # Step 2: Expand all %VAR% environment variables
    $converted = [System.Environment]::ExpandEnvironmentVariables($converted)
    Write-Debug "[Expand-BashVariable] Output: $converted"
    return $converted
}

function Expand-HomePath {
    param(
        [string]$Value
    )
    Write-Debug "[Expand-HomePath] Input: $Value"
    $Value = $Value -replace '~(?=/|$)', "$env:USERPROFILE"
    Write-Debug "[Expand-HomePath] Output: $Value"
    return $Value
}

function Convert-UnixPathToWindows {
    param(
        [string]$Value
    )
    Write-Debug "[Convert-UnixPathToWindows] Input: $Value"
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }
    # Convert slashes to Windows style (optional)
    $Value = $Value -replace '/', '\'
    $MSYS2Path = "$env:USERPROFILE\scoop\apps\msys2\current"
    $Value = $Value -replace '/([cdefghijk])/', '${1}:/'
    $Value = $Value -replace '/usr', "$MSYS2Path/usr"
    $Value = $Value -replace '/mingw', "$MSYS2Path/mingw"
    Write-Debug "[Convert-UnixPathToWindows] Output: $Value"
    return $Value
}

#Encapsulate all string processing in this function
function ProcessString {
    param(
        [string]$InputString
    )

    if ([string]::IsNullOrWhiteSpace($InputString)) {
        Write-Debug "[ProcessString] Input is null or empty."
        return $InputString
    }

    Write-Debug "[ProcessString] Processing raw input: $InputString"

    # Step 1: Remove quotes
    $processed = RemoveQuotes -Value $InputString

    # Step 2: Replace bash command substitution $(...)
    $processed = Convert-BashCommandSubstitution -Value $processed

    # Step 2: Replace bash variable references
    $processed = Expand-BashVariable -Value $processed

    # Step 3: Replace ~ with user directory
    $processed = Expand-HomePath -Value $processed

    # Step 4: Convert Unix path format
    $processed = Convert-UnixPathToWindows -Value $processed

    $processed = Unescape-BashString -Value $processed


    Write-Debug "[ProcessString] Final processed value: $processed"
    return $processed
}

function Parse-BashLine {
    param(
        [string]$Line
    )

    $trimmedLine = $Line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith("#")) {
        Write-Debug "[Parse-BashLine] Skipped (empty or comment): $Line"
        return
    }

    Write-Debug "[Parse-BashLine] Processing line: $trimmedLine"

    # ----------------------------
    # Handle PATH
    # ----------------------------
    if ($trimmedLine -match '^export\s+PATH=(.+)$') {
        Write-Debug "[Parse-BashLine] Matched export PATH"

        $pathValue = ProcessString -InputString $matches[1]

        Write-Debug "[Parse-BashLine] Expanded PATH value: $pathValue"

        $newPaths = ($pathValue -split ':' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

        foreach ($p in $newPaths) {
            $resolvedPath = [System.Environment]::ExpandEnvironmentVariables($p)
            if (Test-Path $resolvedPath -PathType Container) {
                if (-not $env:PATH.Contains($resolvedPath, [System.StringComparison]::InvariantCultureIgnoreCase)) {
                    Write-Debug "[Parse-BashLine] Adding to PATH: $resolvedPath"
                    $env:PATH += ";$resolvedPath"
                }
                else {
                    Write-Debug "[Parse-BashLine] Already in PATH (skipped): $resolvedPath"
                }
            }
            else {
                Write-Debug "[Parse-BashLine] Path does not exist (ignored): $resolvedPath"
            }
        }
        return
    }

    # ----------------------------
    # Handle export VAR=value
    # ----------------------------
    if ($trimmedLine -match '^export\s+(\w+)=(.+)$') {
        Write-Debug "[Parse-BashLine] Matched export VAR=value"

        $varName = $matches[1]
        $value = ProcessString -InputString $matches[2]

        Write-Debug "[Parse-BashLine] Setting env:$varName = $value"
        Set-Item -Path "env:$varName" -Value $value
        return
    }

    # ----------------------------
    # Handle alias name='command'
    # ----------------------------
    if ($trimmedLine -match '^alias\s+(\w+)=(.+)$') {
        Write-Debug "[Parse-BashLine] Matched alias"

        $aliasName = $matches[1]
        $aliasValue = ProcessString -InputString $matches[2]

        Write-Debug "[Parse-BashLine] Alias: $aliasName -> $aliasValue"

        if ($aliasValue -match '\s' -or $aliasValue -match '\$\w+' -or $aliasValue -match '\$\(' ) {
            $scriptBlock = [ScriptBlock]::Create("param(`$args); $aliasValue")
            # $scriptBlock = $aliasValue
            # New-Item -Path Function:\ -Name $aliasName -Value $scriptBlock -Force | Out-Null
            Set-Item -Path "Function:\global:$aliasName" -Value $scriptBlock -Force
            # Set-Item -Path "Function:\$aliasName" -Value $scriptBlock -Scope Global -Force
            # Invoke-Expression "function global:$aliasName { param(`$args); $AliasValue }"
            Write-Debug "[Parse-BashLine] Creating function for alias: $aliasName => $aliasName : $scriptBlock"
        }
        else {
            Write-Debug "[Parse-BashLine] Creating simple alias: $aliasName -> $aliasValue"
            Set-Alias -Name $aliasName -Value $aliasValue -Scope Global -Force
        }
        return
    }

    # ----------------------------
    # Handle regular variable assignment VAR=value
    # ----------------------------
    if ($trimmedLine -match '^(\w+)=(.+)$') {
        Write-Debug "[Parse-BashLine] Matched VAR=value"

        $varName = $matches[1]
        $value = ProcessString -InputString $matches[2]

        Write-Debug "[Parse-BashLine] Setting env:$varName = $value"
        Set-Item -Path "env:$varName" -Value $value
        return
    }

    # ----------------------------
    # Handle source ~/.bash_profile or . ~/.bash_aliases
    # ----------------------------
    if ($trimmedLine -match '^(?:source|\.)\s+(.+)$') {
        Write-Debug "[Parse-BashLine] Matched source or dot command"

        $filePath = ProcessString -InputString $matches[1]

        if ([string]::IsNullOrWhiteSpace($filePath)) {
            Write-Debug "[Parse-BashLine] Source path is empty or invalid: $filePath"
            return
        }

        Write-Debug "[Parse-BashLine] Sourcing file: $filePath"

        # ✅ Recursively call Load-BashRc to load other configuration files
        Load-BashRc -Value $filePath
        return
    }

    # ----------------------------
    # Execute unknown commands
    # ----------------------------
    try {
        Write-Debug "[Parse-BashLine] Attempting to execute command: $trimmedLine"
        $sb = [ScriptBlock]::Create($trimmedLine)
        & $sb
    }
    catch {
        Write-Debug "[Parse-BashLine] Failed to execute line: $trimmedLine"
    }
}

function Load-BashRc {
    param(
        [string]$Value = "$env:USERPROFILE\.bashrc",
        [boolean]$All = $false
    )

    New-Item -Path Function:\ -Name "cdf" -Value "cd '..'"  -Force | Out-Null
    Write-Debug "[Load-BashRc] Loading bashrc file from: $Value"

    if (-not (Test-Path $Value)) {
        Write-Warning "Bashrc file not found at path: $Value"
        return
    }

    $parseLine = $All

    $content = Get-Content -Path $Value -Raw
    $lines = $content -split "`n"

    foreach ($line in $lines) {
        $trimmedLine = $line.TrimStart()

        if ($trimmedLine -match '^#PS') {
            Write-Debug "[Load-BashRc] Found #PS marker, enabling parsing."
            $parseLine = $true
            continue
        }

        if ($trimmedLine -match '^#SP') {
            Write-Debug "[Load-BashRc] Found #SP marker, disabling parsing."
            $parseLine = $false
            continue
        }

        if (-not $parseLine) {
            continue
        }

        Parse-BashLine -Line $line
    }

    Write-Debug "[Bashrc] Configuration applied from: $Value"
}

# Set bash-compatible environment variables
$env:HOME = "$env:USERPROFILE"
$env:PWD = (Get-Location).Path
$env:SHELL = "PowerShell"
$env:USER = "$env:USERNAME"
$env:HOSTNAME = [System.Net.Dns]::GetHostName()
# Load once by default

Load-BashRc




# bin
if (-not [string]::IsNullOrWhiteSpace("$env:USER_BIN_PATH")) {
    Write-Debug "[bin] USER_BIN_PATH is set: $env:USER_BIN_PATH"
    # Check if path exists and is a directory
    if (Test-Path -Path "$env:USER_BIN_PATH" -PathType Container) {
        Get-ChildItem -Path "$env:USER_BIN_PATH" -File | ForEach-Object {
            $fileName = $_.BaseName
            $filePath = $_.FullName

            Write-Debug "[bin] adding $fileName at path: $filePath"
            # Create function dynamically
            # $scriptBlock = [ScriptBlock]::Create("param(`$args);  sh $filePath  @args ")

            $scriptBlock = {
                param(
                    [Parameter(ValueFromRemainingArguments = $true)]
                    $Arguments
                )
                busybox bash $filePath $Arguments
            }.GetNewClosure()


            Set-Item "Function:\global:$fileName" -Value $scriptBlock -Force | Out-Null
        }
    }
    else {
        Write-Warning "Directory does not exist: $env:USER_BIN_PATH"
    }
}

if ( -not [string]::IsNullOrWhiteSpace("$env:USER_PROFILE_D_PATH")) {

    Write-Debug "[bin] USER_PROFILE_D_PATH is set: $env:USER_PROFILE_D_PATH"
    # Check if path exists and is a directory
    if (Test-Path -Path "$env:USER_PROFILE_D_PATH" -PathType Container) {
        
        Get-ChildItem -Path "$env:USER_PROFILE_D_PATH" -File | ForEach-Object {
            $filePath = $_.FullName

            Write-Debug "[profile] loading file: $fileName at path: $filePath"
            Load-BashRc -Value $filePath -All $true
        }
    }
    else {
        Write-Warning "Directory does not exist: $env:USER_PROFILE_D_PATH"
    }
}

