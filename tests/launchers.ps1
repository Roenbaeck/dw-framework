[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$framework = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('sisula-launchers-' + [Guid]::NewGuid().ToString('N'))

try {
    $project = Join-Path $scratch 'project with spaces'
    New-Item -ItemType Directory -Path (Join-Path $project 'sources'), (Join-Path $project 'workflows') -Force | Out-Null
    Copy-Item (Join-Path $framework 'Examples\Golf\Variables.BAT') $project
    Copy-Item (Join-Path $framework 'Examples\Golf\sources\source.xml') (Join-Path $project 'sources')
    Copy-Item (Join-Path $framework 'Examples\Golf\workflows\workflow.xml') (Join-Path $project 'workflows')
    $workflow = Join-Path $project 'workflows\workflow.sql'
    $source = Join-Path $project 'sources\source.sql'

    foreach ($name in @('Sisulate.bat', 'SisulateWSH.bat')) {
        $launcher = Join-Path $framework $name
        $ErrorActionPreference = 'Continue'
        $output = & $launcher $project '""' '/W' 2>&1
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -ne 0) { throw "$name failed:`n$($output -join "`n")" }
        if (-not (Test-Path -LiteralPath $workflow) -or (Test-Path -LiteralPath $source)) {
            throw "$name did not honor the /W filter."
        }
        Remove-Item -LiteralPath $workflow

        $ErrorActionPreference = 'Continue'
        $output = & $launcher (Join-Path $scratch 'missing') 2>&1
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -eq 0) { throw "$name did not report an invalid project." }
        Write-Host "PASS $name"
    }

    $ErrorActionPreference = 'Continue'
    $output = & (Get-Process -Id $PID).Path -NoProfile -File (Join-Path $framework 'Sisulate.ps1') `
        -FolderPath $project -Renderer Sisulator 2>&1
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -eq 0) { throw 'The retired Sisulator renderer was accepted.' }
    Write-Host 'PASS retired renderer rejected'
}
finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
