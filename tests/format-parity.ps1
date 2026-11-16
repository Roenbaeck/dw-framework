[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$framework = Split-Path $PSScriptRoot -Parent
$generator = Join-Path $framework 'Sisulate.ps1'
$powershell = (Get-Process -Id $PID).Path
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('sisula-formats-' + [Guid]::NewGuid().ToString('N'))
. (Join-Path $PSScriptRoot 'Normalize-Sql.ps1')

function Generate-Source([string]$project, [string]$renderer) {
    $ErrorActionPreference = 'Continue'
    $output = & $powershell -NoProfile -File $generator -FolderPath $project -Filters S -Renderer $renderer 3>&1 2>&1
    if ($LASTEXITCODE -ne 0) { throw "$renderer generation failed:`n$($output -join "`n")" }
    if ($renderer -eq 'Sisula' -and ($output -join "`n") -match 'Source SQL .*Sisulator') {
        throw 'The preview must use Sisula for all source SQL.'
    }
}

function Assert-Parity([string]$project, [string]$name) {
    Generate-Source $project 'Sisula'
    foreach ($input in Get-ChildItem (Join-Path $project 'sources') -Filter '*.xml') {
        $actual = [IO.File]::ReadAllText((Join-Path $project ('formats\' + $input.Name)))
        Assert-LegacySnapshot 'format' "$name-$($input.Name)" $actual
        $sql = [IO.File]::ReadAllText((Join-Path $input.DirectoryName ($input.BaseName + '.sql')))
        $actualSql = Normalize-Output $sql -IgnoreGeneratedTime
        Assert-LegacySnapshot 'source' "$name-$($input.Name)" $actualSql
    }
    Write-Host "PASS $name"
}

try {
    New-Item -ItemType Directory -Path $scratch | Out-Null
    foreach ($name in @('Golf', 'Traffic')) {
        $project = Join-Path $scratch $name
        New-Item -ItemType Directory -Path (Join-Path $project 'sources'), (Join-Path $project 'formats') -Force | Out-Null
        Copy-Item (Join-Path $framework "Examples\$name\Variables.BAT") $project
        Copy-Item (Join-Path $framework "Examples\$name\sources\source.xml") (Join-Path $project 'sources')
        Assert-Parity $project $name
    }

    $project = Join-Path $scratch 'edge'
    New-Item -ItemType Directory -Path (Join-Path $project 'sources'), (Join-Path $project 'formats') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $project 'Variables.BAT'), "set System=Edge`r`nset Terminator=END`r`nset MetaDatabase=`r`n")
    $wide = @'
<source name="Wide" split="bulk" datafiletype="widechar" fieldterminator="%Terminator%">
  <part name="Rows">
    <term name="Fixed" size="4" format="varchar(4)"/>
    <term name="Quoted" delimiter="&quot;" format="varchar(20)"/>
    <term name="Last" delimiter="|" format="varchar(20)"/>
  </part>
</source>
'@
    $missing = @'
<source name="MissingTerminator" split="bulk" datafiletype="char">
  <part name="Rows"><term name="Only" format="varchar(10)"/></part>
</source>
'@
    $sentinel = [string][char]0x00a7
    $missing = $missing.Replace('MissingTerminator', ('Missing' + $sentinel + 'DOLLAR' + $sentinel + 'Terminator'))
    $missing = $missing.Replace('name="Only"', ('name="Only' + $sentinel + 'SINGLE' + $sentinel + 'Name' + $sentinel + 'QUOTED' + $sentinel + '"'))
    $regex = @'
<source name="Regex" split="regex" datafiletype="char" fieldterminator="|" rowlength="60" firstrow="0">
  <part name="Rows" charskip="2" nulls="n'o">
    SELECT 'O''Brien' AS [row]
    <term name="Fixed" size="3" format="varchar(3)" nulls="x'y"/>
    <term name="Delimited" delimiter="&apos;" format="varchar(20)">LTRIM('a''b')</term>
    <term name="Pattern" pattern="([a-z']*)" format="varchar(20)"/>
    <term name="Rest" format="varchar(20)"/>
    <key name="Primary" type="primary key"><component of="Fixed"/><component of="Delimited"/></key>
    <key name="Unique" type="unique"><component of="Pattern"/></key>
    <calculation name="Computed" format="varchar(20)" persisted="false">UPPER('a''b')</calculation>
    <calculation name="Empty" format="int"/>
  </part>
  <part name="More" pattern="^x"><term name="Last" delimiter=";" format="int"/></part>
</source>
'@
    [IO.File]::WriteAllText((Join-Path $project 'sources\wide.xml'), $wide)
    [IO.File]::WriteAllText((Join-Path $project 'sources\missing.xml'), $missing)
    [IO.File]::WriteAllText((Join-Path $project 'sources\regex.xml'), $regex)
    Assert-Parity $project 'fixed, quoted, regex, keys and calculations'
    [IO.File]::WriteAllText((Join-Path $project 'Variables.BAT'), "set System=Edge`r`nset Terminator=END`r`nset MetaDatabase=Metadata`r`nset SourceDatabase=Stage`r`n")
    Assert-Parity $project 'wide with metadata and source database'
}
finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
