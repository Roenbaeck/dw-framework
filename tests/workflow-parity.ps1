[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$framework = Split-Path $PSScriptRoot -Parent
$generator = Join-Path $framework 'Sisulate.ps1'
$powershell = (Get-Process -Id $PID).Path
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('sisula-workflows-' + [Guid]::NewGuid().ToString('N'))
. (Join-Path $PSScriptRoot 'Normalize-Sql.ps1')

function Generate-Workflow([string]$project, [string]$renderer) {
    $ErrorActionPreference = 'Continue'
    $output = & $powershell -NoProfile -File $generator -FolderPath $project -Filters W -Renderer $renderer 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "$renderer generation failed:`n$($output -join "`n")"
    }
    $files = Get-ChildItem (Join-Path $project 'workflows') -Filter '*.xml' | Sort-Object Name
    $results = foreach ($file in $files) {
        [IO.File]::ReadAllText((Join-Path $file.DirectoryName ($file.BaseName + '.sql')))
    }
    return ($results -join "`0")
}

function Assert-Parity([string]$project, [string]$name) {
    $new = Normalize-Output (Generate-Workflow $project 'Sisula')
    Assert-LegacySnapshot 'workflow' $name $new
    Write-Host "PASS $name"
}

function Assert-DefaultProject([string]$name, [string]$project) {
    foreach ($folder in @('sources', 'targets', 'formats', 'biml')) {
        $exampleFolder = Join-Path $framework "Examples\$name\$folder"
        if (Test-Path -LiteralPath $exampleFolder) {
            $destination = Join-Path $project $folder
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
            if ($folder -eq 'sources' -or $folder -eq 'targets') {
                Get-ChildItem -LiteralPath $exampleFolder -Filter '*.xml' |
                    Copy-Item -Destination $destination
            }
        }
    }
    $ErrorActionPreference = 'Continue'
    $output = & $powershell -NoProfile -File $generator -FolderPath $project 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Default $name generation failed:`n$($output -join "`n")" }
    foreach ($folder in @('sources', 'targets', 'workflows')) {
        Get-ChildItem -LiteralPath (Join-Path $project $folder) -Filter '*.xml' | ForEach-Object {
            $sql = Join-Path $_.DirectoryName ($_.BaseName + '.sql')
            if (-not (Test-Path -LiteralPath $sql) -or (Get-Item -LiteralPath $sql).Length -eq 0) {
                throw "Default $name generation did not produce '$sql'."
            }
            if ($folder -eq 'sources' -and (Test-Path (Join-Path $project 'formats'))) {
                $format = Join-Path $project ('formats\' + $_.BaseName + '.xml')
                if (-not (Test-Path -LiteralPath $format) -or (Get-Item -LiteralPath $format).Length -eq 0) {
                    throw "Default $name generation did not produce '$format'."
                }
            }
            if ($folder -eq 'targets' -and (Test-Path (Join-Path $project 'biml'))) {
                $biml = Join-Path $project ('biml\' + $_.BaseName + '.biml')
                if (-not (Test-Path -LiteralPath $biml) -or (Get-Item -LiteralPath $biml).Length -eq 0) {
                    throw "Default $name generation did not produce '$biml'."
                }
            }
        }
    }
    Write-Host "PASS default $name STW generation"
}

try {
    New-Item -ItemType Directory -Path $scratch | Out-Null
    foreach ($name in @('Golf', 'Traffic')) {
        $project = Join-Path $scratch $name
        New-Item -ItemType Directory -Path (Join-Path $project 'workflows') -Force | Out-Null
        Copy-Item (Join-Path $framework "Examples\$name\Variables.BAT") $project
        Copy-Item (Join-Path $framework "Examples\$name\workflows\workflow.xml") (Join-Path $project 'workflows')
        Assert-Parity $project $name
        Assert-DefaultProject $name $project
    }

    $project = Join-Path $scratch 'edge'
    New-Item -ItemType Directory -Path (Join-Path $project 'workflows') -Force | Out-Null
    $xml = @'
<workflow name="%System%_workflow">
  <variable name="v" value="workflow"/>
  <job name="%System%_first" enabled="0" start_step_id="0" category_name="test" category_id="0" notify_level_eventlog="0" notify_level_email="0" notify_level_netsend="0" notify_level_page="0" notify_email_operator_name="email" notify_netsend_operator_name="netsend" notify_page_operator_name="page" delete_level="0" owner_login_name="owner">
    description
    <variable name="v" value="job"/>
    <jobstep name="one" step_id="0" subsystem="TSQL" additional_parameters="params" cmdexec_success_code="0" server="server" database_name="db" database_user_name="user" retry_attempts="0" retry_interval="0" os_run_priority="0" output_file_name="file" flags="0" proxy_id="0" proxy_name="proxy" on_fail_action="0" on_fail_step_id="0" on_success_action="3" on_success_step_id="0">select '%v%', '$value$', 'O''Brien';</jobstep>
    <jobstep name="two" subsystem="PowerShell" flags="0">Write-Output '%v%'</jobstep>
  </job>
  <job name="second"><jobstep name="other" subsystem="TSQL">select '%v%';</jobstep></job>
</workflow>
'@
    [IO.File]::WriteAllText((Join-Path $project 'workflows\workflow.xml'), $xml)
    [IO.File]::WriteAllText((Join-Path $project 'workflows\other.xml'), '<workflow name="other"><job name="other"><jobstep name="only">SELECT 1</jobstep></job></workflow>')
    foreach ($metadata in @('', 'TestMetadata')) {
        [IO.File]::WriteAllText((Join-Path $project 'Variables.BAT'), "set System=Edge`r`nset MetaDatabase=$metadata`r`n")
        Assert-Parity $project "edge metadata='$metadata'"
    }

    $sentinel = Join-Path $project 'workflows\workflow.sql'

    $isolated = Join-Path $scratch 'framework'
    New-Item -ItemType Directory -Path (Join-Path $isolated 'code\DLL'), (Join-Path $isolated 'sisulets\workflow') -Force | Out-Null
    foreach ($file in @('Sisulate.ps1', 'Objectifier4PS.js', 'code\sisula.js', 'code\VariablesBat.ps1', 'code\DLL\Jint.2.11.58.dll',
                        'sisulets\Variables.js', 'sisulets\workflow\Variables.js', 'sisulets\workflow\Bindings.js')) {
        Copy-Item -LiteralPath (Join-Path $framework $file) -Destination (Join-Path $isolated $file)
    }
    $script:generator = Join-Path $isolated 'Sisulate.ps1'
    [IO.File]::WriteAllText((Join-Path $isolated 'first.sisula'), "first:`$workflow.name`$`n")
    [IO.File]::WriteAllText((Join-Path $isolated 'second.sisula'), "second:`$workflow.name`$`n")
    [IO.File]::WriteAllText((Join-Path $isolated 'empty.sisula'), '')
    [IO.File]::WriteAllText((Join-Path $isolated 'workflow.sisula.directive'), "# comment`r`nfirst.sisula`r`nempty.sisula`r`nsecond.sisula`r`n")
    $null = Generate-Workflow $project 'Sisula'
    $directiveOutput = [IO.File]::ReadAllText($sentinel)
    if ($directiveOutput -cne "first:Edge_workflow`nsecond:Edge_workflow`n") {
        throw "Workflow directive templates were not rendered in order with the resolved bindings: $directiveOutput"
    }
    Write-Host 'PASS directive order and bindings'

    [IO.File]::WriteAllText((Join-Path $isolated 'workflow.sisula.directive'), 'missing.sisula')
    [IO.File]::WriteAllText($sentinel, 'unchanged')
    $ErrorActionPreference = 'Continue'
    $output = & $powershell -NoProfile -File $generator -FolderPath $project -Filters W -Renderer Sisula 2>&1
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -eq 0 -or ($output -join "`n") -notmatch 'missing.sisula' -or
        [IO.File]::ReadAllText($sentinel) -ne 'unchanged') {
        throw 'A missing template must fail without overwriting the output.'
    }
    Write-Host 'PASS missing template rejected'
}
finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
