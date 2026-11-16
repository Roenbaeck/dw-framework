[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$framework = Split-Path $PSScriptRoot -Parent
$generator = Join-Path $framework 'Sisulate.ps1'
$powershell = (Get-Process -Id $PID).Path
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('sisula-biml-' + [Guid]::NewGuid().ToString('N'))
. (Join-Path $PSScriptRoot 'Normalize-Sql.ps1')

function Normalize-Biml([string]$text) {
    $insideSql = $false
    $lines = $text -split "`n"
    $normalized = foreach ($line in $lines) {
        $opens = $line.Contains('<DirectInput>')
        $closes = $line.Contains('</DirectInput>')
        if (-not $insideSql -and -not $opens) {
            $line = $line.TrimEnd([char[]]@(' ', "`t", "`r"))
            $line = $line -replace '^( *<Annotation AnnotationType="Description">BIML generated: ).*? by ', '$1<timestamp> by '
        }
        elseif ($closes) {
            $line = $line.TrimEnd([char[]]@(' ', "`t", "`r"))
        }
        if ($opens -and -not $closes) { $insideSql = $true }
        if ($closes) { $insideSql = $false }
        $line
    }
    return ($normalized -join "`n")
}

function Generate-Biml([string]$project, [string]$renderer) {
    $ErrorActionPreference = 'Continue'
    $output = & $powershell -NoProfile -File $generator -FolderPath $project -Filters T -Renderer $renderer 2>&1
    if ($LASTEXITCODE -ne 0) { throw "$renderer generation failed:`n$($output -join "`n")" }
}

function Assert-Parity([string]$project, [string]$name) {
    Generate-Biml $project 'Sisula'
    foreach ($input in Get-ChildItem (Join-Path $project 'targets') -Filter '*.xml') {
        $file = Join-Path $project ('biml\' + $input.BaseName + '.biml')
        $actual = Normalize-Biml ([IO.File]::ReadAllText($file))
        Assert-LegacySnapshot 'biml' "$name-$($input.Name)" $actual
    }
    Write-Host "PASS $name"
}

try {
    New-Item -ItemType Directory -Path $scratch | Out-Null
    foreach ($name in @('Traffic')) {
        $project = Join-Path $scratch $name
        New-Item -ItemType Directory -Path (Join-Path $project 'targets'), (Join-Path $project 'biml') -Force | Out-Null
        Copy-Item (Join-Path $framework "Examples\$name\Variables.BAT") $project
        Copy-Item (Join-Path $framework "Examples\$name\targets\target.xml") (Join-Path $project 'targets')
        Assert-Parity $project $name
    }

    $project = Join-Path $scratch 'edge'
    New-Item -ItemType Directory -Path (Join-Path $project 'targets'), (Join-Path $project 'biml') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $project 'Variables.BAT'),
        "set SourceDatabase=Stage`r`nset SourceServer=Source`r`nset TargetDatabase=DW`r`nset TargetServer=Target`r`nset TargetSchema=dbo`r`nset MetaDatabase=`r`n")
    $xml = @'
<target name="Edge" database="DW">
  <load source="NaturalStage" target="lAA_Thing">
    <sql position="before">select 'before';</sql>
    select 'O''Brien' as Name, '$value$' as Status
    <map source="Name" target="AA_NAM_Thing_Name" as="natural key" attribute="AA_NAM_Thing_Name"/>
    <map source="Changed" target="AA_NAM_ChangedAt"/>
    <map source="Status" target="AA_STA_Thing_Status" attribute="AA_STA_Thing_Status" knot="KNT_Status"/>
    <map source="OtherStatus" target="AA_ST2_Thing_Status2" attribute="AA_ST2_Thing_Status2" knot="KNT_Status"/>
    <map source="Meta" target="Metadata_AA" as="metadata"/>
    <sql position="after">select 'after';</sql>
  </load>
  <load source="SurrogateStage" target="lBB_Person">
    <map source="ID" target="BB_ID" as="surrogate key"/>
    <map source="Name" target="BB_NAM_Person_Name" attribute="BB_NAM_Person_Name"/>
  </load>
  <load source="NoKeyStage" target="lCC_Item">
    <map source="Value" target="Value"/>
  </load>
  <load source="OtherStage" target="lDD_Thing_extra">
    <map source="Key" target="Key" as="natural key"/>
  </load>
</target>
'@
    [IO.File]::WriteAllText((Join-Path $project 'targets\edge.xml'), $xml)
    Assert-Parity $project 'natural, surrogate, knot, attribute and no-key cases'
}
finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
