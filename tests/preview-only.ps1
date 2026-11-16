[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$framework = Split-Path $PSScriptRoot -Parent
$powershell = (Get-Process -Id $PID).Path
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('sisula-preview-' + [Guid]::NewGuid().ToString('N'))

try {
    $isolated = Join-Path $scratch 'framework'
    $project = Join-Path $scratch 'project'
    New-Item -ItemType Directory -Path (Join-Path $isolated 'code\DLL'), (Join-Path $project 'sources'),
        (Join-Path $project 'targets'), (Join-Path $project 'workflows'), (Join-Path $project 'formats'),
        (Join-Path $project 'biml') -Force | Out-Null
    foreach ($file in @('Sisulate.ps1', 'Objectifier4PS.js', 'code\sisula.js', 'code\VariablesBat.ps1', 'code\DLL\Jint.2.11.58.dll',
                        'format.sisula.directive', 'source.sisula.directive', 'target.sisula.directive',
                        'biml.sisula.directive', 'workflow.sisula.directive')) {
        Copy-Item -LiteralPath (Join-Path $framework $file) -Destination (Join-Path $isolated $file)
    }
    Copy-Item -LiteralPath (Join-Path $framework 'sisulets') -Destination (Join-Path $isolated 'sisulets') -Recurse
    Copy-Item (Join-Path $framework 'Examples\Golf\Variables.BAT') $project
    Copy-Item (Join-Path $framework 'Examples\Golf\sources\source.xml') (Join-Path $project 'sources')
    Copy-Item (Join-Path $framework 'Examples\Traffic\targets\target.xml') (Join-Path $project 'targets')
    Copy-Item (Join-Path $framework 'Examples\Golf\workflows\workflow.xml') (Join-Path $project 'workflows')
    $ErrorActionPreference = 'Continue'
    $output = & $powershell -NoProfile -File (Join-Path $isolated 'Sisulate.ps1') -FolderPath $project 2>&1
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) { throw "Preview generation failed:`n$($output -join "`n")" }
    foreach ($file in @('formats\source.xml', 'sources\source.sql', 'targets\target.sql',
                        'biml\target.biml', 'workflows\workflow.sql')) {
        $path = Join-Path $project $file
        if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -eq 0) {
            throw "The preview did not produce '$file'."
        }
    }
    Write-Host 'PASS all pipelines without the legacy evaluator'
}
finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
