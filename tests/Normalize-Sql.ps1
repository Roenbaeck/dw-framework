foreach ($name in @('USERNAME', 'COMPUTERNAME', 'USERDOMAIN', 'System', 'Source', 'SourceSchema',
                     'SourceDatabase', 'SourceServer', 'TargetSchema', 'TargetDatabase', 'TargetServer',
                     'MetaDatabase', 'Timestamp')) {
    Set-Item -Path ("Env:" + $name) -Value ''
}
$env:USERNAME = 'test-user'
$env:COMPUTERNAME = 'test-computer'
$env:USERDOMAIN = 'test-domain'

function Get-LegacySnapshotPath([string]$suite, [string]$name) {
    $safeName = $name -replace '[^a-zA-Z0-9._-]', '_'
    return Join-Path $PSScriptRoot ("golden\legacy\" + $suite + '-' + $safeName + '.txt')
}

function Normalize-Snapshot([string]$text) {
    return $text.Replace($scratch, '<SCRATCH>').Replace($framework, '<FRAMEWORK>').Replace([string][char]0, '<WORKFLOW-END>')
}

function Assert-LegacySnapshot([string]$suite, [string]$name, [string]$text) {
    $path = Get-LegacySnapshotPath $suite $name
    $expected = [IO.File]::ReadAllText($path)
    $actual = Normalize-Snapshot $text
    if ($expected -cne $actual) {
        $oldLines = $expected -split "`n"
        $newLines = $actual -split "`n"
        $n = [Math]::Min($oldLines.Length, $newLines.Length)
        $i = 0
        while ($i -lt $n -and $oldLines[$i] -ceq $newLines[$i]) { $i++ }
        $oldLine = if ($i -lt $oldLines.Length) { $oldLines[$i] } else { '<end of output>' }
        $newLine = if ($i -lt $newLines.Length) { $newLines[$i] } else { '<end of output>' }
        throw "$suite/$name differs from the legacy snapshot at line $($i + 1):`n  Expected: $oldLine`n  Actual:   $newLine"
    }
}

function Normalize-Output([string]$sql, [switch]$IgnoreGeneratedTime) {
    $result = New-Object Text.StringBuilder
    $pending = ''
    $literal = $false
    $identifier = $false
    $comment = $false
    for ($i = 0; $i -lt $sql.Length; $i++) {
        $c = $sql[$i]
        $next = if ($i + 1 -lt $sql.Length) { $sql[$i + 1] } else { [char]0 }
        if ($IgnoreGeneratedTime -and -not $literal -and -not $identifier -and -not $comment -and
            $c -eq '-' -and $sql.Substring($i).StartsWith('-- Generated: ')) {
            $end = $sql.IndexOf("`n", $i)
            if ($end -lt 0) { $end = $sql.Length }
            $line = $sql.Substring($i, $end - $i)
            [void]$result.Append($pending)
            [void]$result.Append(($line -replace '^-- Generated: .*? by ', '-- Generated: <timestamp> by '))
            $pending = ''
            $i = $end - 1
            continue
        }
        if (-not $literal -and -not $identifier -and ($c -eq ' ' -or $c -eq "`t")) {
            $pending += $c
            continue
        }
        if ($c -eq "`r" -or $c -eq "`n") {
            if ($literal -or $identifier) { [void]$result.Append($pending) }
            $pending = ''
            [void]$result.Append($c)
            $comment = $false
            continue
        }
        [void]$result.Append($pending)
        $pending = ''
        [void]$result.Append($c)
        if ($comment) { continue }
        if ($literal -and $c -eq "'" -and $next -eq "'") {
            [void]$result.Append($next)
            $i++
        }
        elseif ($identifier -and $c -eq ']' -and $next -eq ']') {
            [void]$result.Append($next)
            $i++
        }
        elseif ($literal -and $c -eq "'") { $literal = $false }
        elseif ($identifier -and $c -eq ']') { $identifier = $false }
        elseif (-not $literal -and -not $identifier -and $c -eq '-' -and $next -eq '-') { $comment = $true }
        elseif (-not $identifier -and $c -eq "'") { $literal = $true }
        elseif (-not $literal -and $c -eq '[') { $identifier = $true }
    }
    return $result.ToString()
}
