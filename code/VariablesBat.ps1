#-------------------------------------------------------------------
# Reads the variables of a project's Variables.BAT without running it.
#
# The framework used to run the file with CALL, so it could hold anything a batch file can. It is now read, line by line, and the
# part of the batch language that sets variables is interpreted here:
#
#   set NAME=value             set "NAME=value"             @set NAME=value
#   set A=1 & set B=2          (also &&; the commands of a line are run in order)
#   %NAME%                     the value of a variable set earlier in the file, or of an environment variable (empty if there is none)
#   %%                         a percent sign
#   %~dp0 %~f0 %~d0 %~p0 %~n0 %~x0 %~nx0 %~dpnx0 %0     the file itself, as in a batch file
#   if defined NAME <command>      if not defined NAME <command>
#   if "a"=="b" <command>          if not "a"=="b" <command>        if /i ...   (after %NAME% has been expanded)
#   REM ...   ::   echo ...   setlocal   endlocal   title   cls   color   pause     (nothing to do here: ignored)
#
# Anything else is NOT run, and says so with a warning that has the line number and the line: set /a and set /p, call, goto, for,
# labels, exit, if exist, if errorlevel, %NAME:a=b% and %NAME:~1,2%, redirection and pipes, a command that is not a batch command
# that sets a variable. A variable that such a line would have set is then missing; the warning is how it is found.
#
# Returns a hashtable of the variables that the file sets (not the environment). Names are not case sensitive, as in a batch file.
#-------------------------------------------------------------------

# splits a line into commands at & and && that are outside double quotes
function Split-BatchCommands {
    param([string]$Line)
    $commands = New-Object System.Collections.Generic.List[string]
    $current = New-Object System.Text.StringBuilder
    $quoted = $false
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $c = $Line[$i]
        if ($c -eq '"') { $quoted = -not $quoted }
        if (-not $quoted -and $c -eq '&') {
            $commands.Add($current.ToString())
            [void]$current.Clear()
            if ($i + 1 -lt $Line.Length -and $Line[$i + 1] -eq '&') { $i++ }
            continue
        }
        [void]$current.Append($c)
    }
    $commands.Add($current.ToString())
    return @($commands | Where-Object { $_.Trim().Length -gt 0 })
}

function Import-VariablesFromBatchFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BatchFilePath,
        # the environment, whose variables %NAME% may name (a hashtable of name and value)
        [hashtable]$Environment = @{}
    )
    $variableMap = @{}
    $file = Get-Item -LiteralPath $BatchFilePath
    $lineNumber = 0
    $line = ''

    function Get-Defined([string]$name) {
        $name = $name.Trim()
        if ($variableMap.ContainsKey($name)) { return ([string]$variableMap[$name]).Length -gt 0 }
        if ($Environment.ContainsKey($name)) { return ([string]$Environment[$name]).Length -gt 0 }
        return $false
    }

    function Expand-Percent([string]$text) {
        $result = New-Object System.Text.StringBuilder
        $i = 0
        while ($i -lt $text.Length) {
            if ($text[$i] -ne '%') { [void]$result.Append($text[$i]); $i++; continue }
            if ($i + 1 -lt $text.Length -and $text[$i + 1] -eq '%') { [void]$result.Append('%'); $i += 2; continue }
            $rest = $text.Substring($i)
            if ($rest -match '^%(~[dpnxf]+)?0') {
                $modifiers = $matches[1]
                $value = $file.FullName
                if ($modifiers) {
                    $m = $modifiers.Substring(1)
                    if ($m -eq 'f') { $value = $file.FullName }
                    else {
                        $value = ''
                        if ($m.Contains('d')) { $value += $file.DirectoryName.Substring(0, 2) }
                        if ($m.Contains('p')) { $value += $file.DirectoryName.Substring(2) + '\' }
                        if ($m.Contains('n')) { $value += $file.BaseName }
                        if ($m.Contains('x')) { $value += $file.Extension }
                    }
                } else { $value = $file.Name }
                [void]$result.Append($value)
                $i += $matches[0].Length
                continue
            }
            if ($rest -match '^%([^%:~\s][^%:]*)%') {
                $name = $matches[1]
                $value = $null
                if ($variableMap.ContainsKey($name)) { $value = [string]$variableMap[$name] }
                elseif ($Environment.ContainsKey($name)) { $value = [string]$Environment[$name] }
                else { Write-Warning "${BatchFilePath}:${lineNumber}: %$name% is not defined here and is taken as empty: $line" ; $value = '' }
                [void]$result.Append($value)
                $i += $matches[0].Length
                continue
            }
            if ($rest -match '^%[^%\s]*:[^%]*%') {
                Write-Warning "${BatchFilePath}:${lineNumber}: a substitution or a substring of a variable (%NAME:...%) is not supported; the text is kept as it is: $line"
                [void]$result.Append($matches[0]); $i += $matches[0].Length; continue
            }
            [void]$result.Append('%'); $i++   # a percent sign that starts nothing
        }
        return $result.ToString()
    }

    function Invoke-BatchCommand([string]$command) {
        $command = $command.Trim()
        if ($command.StartsWith('@')) { $command = $command.Substring(1).Trim() }
        if ($command.Length -eq 0) { return }
        if ($command -match '^(rem|echo|setlocal|endlocal|title|cls|color|pause)(\s|$|\.)' -or $command.StartsWith('::')) { return }
        if ($command -match '^if\s+(/i\s+)?(not\s+)?defined\s+(\S+)\s+(.+)$') {
            $defined = Get-Defined $matches[3]
            if ($matches[2]) { $defined = -not $defined }
            if ($defined) { Invoke-BatchCommand $matches[4] }
            return
        }
        if ($command -match '^if\s+(/i\s+)?(not\s+)?("[^"]*"|\S+?)\s*==\s*("[^"]*"|\S+?)\s+(.+)$') {
            $left = Expand-Percent $matches[3]; $right = Expand-Percent $matches[4]
            $equal = if ($matches[1]) { $left -ieq $right } else { $left -ceq $right }
            if ($matches[2]) { $equal = -not $equal }
            if ($equal) { Invoke-BatchCommand $matches[5] }
            return
        }
        if ($command -match '^set(\s+(.*))?$') {
            $argument = $matches[2]
            if ($null -eq $argument -or $argument.Trim().Length -eq 0) { return }   # a bare SET lists the variables
            $argument = Expand-Percent $argument
            if ($argument -match '^/[aApP]\b') {
                Write-Warning "${BatchFilePath}:${lineNumber}: set /a and set /p are not supported, so the line was not run: $line"
                return
            }
            if ($argument -match '[|<>]') {
                Write-Warning "${BatchFilePath}:${lineNumber}: redirection and pipes are not supported, so the line was not run: $line"
                return
            }
            $argument = $argument.Trim()
            if ($argument.StartsWith('"')) {
                # set "NAME=value": the value ends at the last quote
                $end = $argument.LastIndexOf('"')
                if ($end -gt 0) { $argument = $argument.Substring(1, $end - 1) } else { $argument = $argument.Substring(1) }
            }
            if ($argument -match '^([^=]+?)\s*=(.*)$') {
                $variableMap[$matches[1].Trim()] = $matches[2].Trim()
            } else {
                Write-Warning "${BatchFilePath}:${lineNumber}: set without NAME=value was not run: $line"
            }
            return
        }
        Write-Warning "${BatchFilePath}:${lineNumber}: is not supported, so it was not run: $line"
    }

    foreach ($rawLine in Get-Content -LiteralPath $BatchFilePath) {
        $lineNumber++
        $line = $rawLine.Trim()
        if ($line.Length -eq 0) { continue }
        if ($line -match '^@?(rem|::)' -and ($line -match '^@?::' -or $line -match '^@?rem(\s|$)')) { continue }
        if ($line.StartsWith(':') -and -not $line.StartsWith('::')) {
            Write-Warning "${BatchFilePath}:${lineNumber}: a label is not supported (goto and call are not run): $line"
            continue
        }
        foreach ($command in (Split-BatchCommands $line)) { Invoke-BatchCommand $command }
    }
    return $variableMap
}
