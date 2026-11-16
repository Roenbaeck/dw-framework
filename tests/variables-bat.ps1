[CmdletBinding()]
param()

# What code\VariablesBat.ps1 understands of a Variables.BAT, and what it says about the rest.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$framework = Split-Path $PSScriptRoot -Parent
. (Join-Path $framework 'code\VariablesBat.ps1')
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('sisula-variables-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null

function Read-Bat([string[]]$lines, [hashtable]$environment = @{}) {
    $path = Join-Path $scratch 'Variables.BAT'
    [IO.File]::WriteAllLines($path, $lines, (New-Object Text.UTF8Encoding($false)))
    $output = @(Import-VariablesFromBatchFile -BatchFilePath $path -Environment $environment 3>&1)
    $warnings = @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] } | ForEach-Object { $_.Message })
    $variables = @($output | Where-Object { $_ -is [hashtable] })[0]
    [pscustomobject]@{ Variables = $variables; Warnings = $warnings; Path = $path }
}
function Dump($r) { ($r.Variables.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value }) -join '; ' }
function Check([string]$name, [bool]$ok, [string]$detail = '') {
    if (-not $ok) { throw "FAIL $name $detail" }
    Write-Host "PASS $name"
}

try {
    # a project's own file, as the examples have it: nothing to warn about, the same values as before
    foreach ($example in 'Golf', 'Traffic') {
        $file = Join-Path $framework "Examples\$example\Variables.BAT"
        $output = @(Import-VariablesFromBatchFile -BatchFilePath $file 3>&1)
        $variables = @($output | Where-Object { $_ -is [hashtable] })[0]
        $warnings = @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        Check "$example example: its set lines and no warning" ($variables.Count -ge 4 -and $variables['System'] -and $warnings.Count -eq 0) ($warnings -join '; ')
    }

    $r = Read-Bat @('set System=PGA', 'SET Source=Kaggle', '  set  TargetSchema = dbo ', 'REM set Commented=1', ':: set AlsoCommented=1')
    Check 'plain set lines, any case and spacing; comments ignored' ($r.Variables.Count -eq 3 -and $r.Variables['System'] -eq 'PGA' -and $r.Variables['Source'] -eq 'Kaggle' -and $r.Variables['TargetSchema'] -eq 'dbo' -and $r.Warnings.Count -eq 0) ($r.Warnings -join '; ')

    $r = Read-Bat @('@ECHO OFF', 'setlocal enabledelayedexpansion', 'echo Setting variables found in:', 'echo   %~f0', '@set AtSign=1', 'title x', 'endlocal')
    Check '@set, and echo, setlocal, title and endlocal are ignored without a warning' ($r.Variables['AtSign'] -eq '1' -and $r.Variables.Count -eq 1 -and $r.Warnings.Count -eq 0) ($r.Warnings -join '; ')

    $r = Read-Bat @('set System=PGA', 'set Target=%System%_DW', 'set FromEnv=%COMPUTED%\x', 'set Percent=100%%') @{ COMPUTED = 'env' }
    Check '%NAME% is expanded from earlier lines and from the environment; %% is a percent sign' ($r.Variables['Target'] -eq 'PGA_DW' -and $r.Variables['FromEnv'] -eq 'env\x' -and $r.Variables['Percent'] -eq '100%' -and $r.Warnings.Count -eq 0) (Dump $r)

    $r = Read-Bat @('set Later=%NOTSET%x')
    Check 'an undefined %NAME% is empty and says so' ($r.Variables['Later'] -eq 'x' -and $r.Warnings.Count -eq 1 -and $r.Warnings[0] -match 'NOTSET')

    $r = Read-Bat @('set "Quoted=value with space"', 'set "Odd=a"b"', 'set Keep="in quotes"')
    Check 'set "NAME=value" takes the value inside the quotes; quotes in a value stay' ($r.Variables['Quoted'] -eq 'value with space' -and $r.Variables['Odd'] -eq 'a"b' -and $r.Variables['Keep'] -eq '"in quotes"') (Dump $r)

    $r = Read-Bat @('set Two=a & set Three=b', 'set Four=c && set Five=d', 'set "WithAmp=a&b"')
    Check 'commands joined with & and && are run in order; an & inside quotes is a character' ($r.Variables['Two'] -eq 'a' -and $r.Variables['Three'] -eq 'b' -and $r.Variables['Four'] -eq 'c' -and $r.Variables['Five'] -eq 'd' -and $r.Variables['WithAmp'] -eq 'a&b') (Dump $r)

    $r = Read-Bat @('set A=1', 'if not defined A set A=default', 'if not defined B set B=default', 'if defined A set C=yes', 'if defined NOPE set D=no')
    Check 'if defined and if not defined' ($r.Variables['A'] -eq '1' -and $r.Variables['B'] -eq 'default' -and $r.Variables['C'] -eq 'yes' -and -not $r.Variables.ContainsKey('D') -and $r.Warnings.Count -eq 0) ($r.Warnings -join '; ')

    $r = Read-Bat @('set A=1', 'if "%A%"=="1" set One=yes', 'if not "%A%"=="1" set NotOne=yes', 'if /i "%A%"=="X" set X=no', 'set L=Abc', 'if /i "%L%"=="aBC" set Same=yes', 'if "%L%"=="aBC" set Exact=no')
    Check 'if "a"=="b", with not and /i' ($r.Variables['One'] -eq 'yes' -and -not $r.Variables.ContainsKey('NotOne') -and -not $r.Variables.ContainsKey('X') -and $r.Variables['Same'] -eq 'yes' -and -not $r.Variables.ContainsKey('Exact') -and $r.Warnings.Count -eq 0) ($r.Warnings -join '; ')

    $r = Read-Bat @('set Here=%~dp0', 'set Full=%~f0', 'set Name=%~n0', 'set NameExt=%~nx0', 'set Drive=%~d0')
    $folder = Split-Path $r.Path -Parent
    Check '%~dp0 and the other parameter forms of the file itself' ($r.Variables['Here'] -eq ($folder + '\') -and $r.Variables['Full'] -eq $r.Path -and $r.Variables['Name'] -eq 'Variables' -and $r.Variables['NameExt'] -eq 'Variables.BAT' -and $r.Variables['Drive'] -eq $folder.Substring(0, 2)) (Dump $r)

    $r = Read-Bat @('set Before=1', 'set /a Num=1+2', 'set /p Ask=Which?', 'call other.bat', 'goto :end', 'for %%i in (a b) do set X=%%i', ':label', 'if exist x.txt set E=1', 'set Sub=%Before:1=2%', 'set Out=a>b', 'dir', 'set After=2')
    Check 'what is not understood is not run and is warned about, one warning for each line' ($r.Variables['Before'] -eq '1' -and $r.Variables['After'] -eq '2' -and -not $r.Variables.ContainsKey('Num') -and -not $r.Variables.ContainsKey('E') -and -not $r.Variables.ContainsKey('X') -and $r.Warnings.Count -eq 10) ("warnings: " + $r.Warnings.Count + "`n" + ($r.Warnings -join "`n"))
    Check 'a warning has the file, the line number and the line' ($r.Warnings[0] -match 'Variables\.BAT:2:' -and $r.Warnings[0] -match 'set /a') $r.Warnings[0]
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
