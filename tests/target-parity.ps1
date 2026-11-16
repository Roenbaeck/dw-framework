[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$framework = Split-Path $PSScriptRoot -Parent
$generator = Join-Path $framework 'Sisulate.ps1'
$powershell = (Get-Process -Id $PID).Path
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('sisula-targets-' + [Guid]::NewGuid().ToString('N'))
. (Join-Path $PSScriptRoot 'Normalize-Sql.ps1')

function Generate-Targets([string]$project, [string]$renderer) {
    $ErrorActionPreference = 'Continue'
    $output = & $powershell -NoProfile -File $generator -FolderPath $project -Filters T -Renderer $renderer 3>&1 2>&1
    if ($LASTEXITCODE -ne 0) { throw "$renderer generation failed:`n$($output -join "`n")" }
    if ($renderer -eq 'Sisula' -and ($output -join "`n") -match 'BIML .*Sisulator') {
        throw 'The preview must use Sisula for BIML.'
    }
}

function Assert-Parity([string]$project, [string]$name) {
    Generate-Targets $project 'Sisula'
    foreach ($input in Get-ChildItem (Join-Path $project 'targets') -Filter '*.xml') {
        $sql = [IO.File]::ReadAllText((Join-Path $input.DirectoryName ($input.BaseName + '.sql')))
        $actual = Normalize-Output $sql -IgnoreGeneratedTime
        Assert-LegacySnapshot 'target' "$name-$($input.Name)" $actual
        if (Test-Path (Join-Path $project 'biml')) {
            $biml = Join-Path $project ('biml\' + $input.BaseName + '.biml')
            if (-not (Test-Path -LiteralPath $biml) -or (Get-Item -LiteralPath $biml).Length -eq 0) {
                throw "The preview did not produce '$biml'."
            }
        }
    }
    Write-Host "PASS $name"
}

try {
    New-Item -ItemType Directory -Path $scratch | Out-Null
    foreach ($name in @('Golf', 'Traffic')) {
        $project = Join-Path $scratch $name
        New-Item -ItemType Directory -Path (Join-Path $project 'targets') -Force | Out-Null
        if (Test-Path (Join-Path $framework "Examples\$name\biml")) {
            New-Item -ItemType Directory -Path (Join-Path $project 'biml') | Out-Null
        }
        Copy-Item (Join-Path $framework "Examples\$name\Variables.BAT") $project
        Copy-Item (Join-Path $framework "Examples\$name\targets\target.xml") (Join-Path $project 'targets')
        Assert-Parity $project $name
    }

    $project = Join-Path $scratch 'edge'
    New-Item -ItemType Directory -Path (Join-Path $project 'targets') -Force | Out-Null
    $xml = @'
<target name="Edge" database="%TargetDatabase%" temporalization="%Temporal%">
  <load source="StageInsert" target="InsertTable" type="insert">
    <map source="s1" target="Natural" as="natural key"/>
    <map source="s2" target="Surrogate" as="surrogate key"/>
    <map source="s3" target="Metadata" as="metadata"/>
    <map source="s4" target="Value"/>
  </load>
  <load source="StageQuery" target="InsertQuery" type="insert">
    select 'O''Brien' as s1
    <map source="s1" target="Value"/>
  </load>
  <load source="StageMerge" target="MergeTable">
    <sql position="before">select 'before';</sql>
    select s1, s2 from StageMerge
    <condition>[source].[s1] &gt; 0</condition>
    <map source="s1" target="Key" as="natural key"/>
    <map source="s2" target="StaticField" as="static" deletable="true"/>
    <map source="s3" target="ValueField" deletable="true"/>
    <map source="s4" target="HistoryField" as="history"/>
    <map source="s5" target="OpinionField" as="opinion"/>
    <map source="s6" target="Metadata" as="metadata"/>
    <sql position="after">select 'after';</sql>
  </load>
  <load source="StageKeys" target="KeysOnly">
    <map source="s1" target="Key" as="surrogate key"/>
  </load>
</target>
'@
    [IO.File]::WriteAllText((Join-Path $project 'targets\edge.xml'), $xml)
    foreach ($temporal in @('uni', 'crt')) {
        foreach ($metadata in @('', 'TestMetadata')) {
            [IO.File]::WriteAllText((Join-Path $project 'Variables.BAT'),
                "set TargetDatabase=DW`r`nset SourceDatabase=`r`nset Temporal=$temporal`r`nset MetaDatabase=$metadata`r`n")
            Assert-Parity $project "$temporal metadata='$metadata'"
        }
    }
}
finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
