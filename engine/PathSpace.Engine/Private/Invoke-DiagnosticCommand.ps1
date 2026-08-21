function Invoke-DiagnosticCommand {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$FileName,[string[]]$Arguments=@(),[int]$TimeoutSeconds=10)
    $command=Get-Command $FileName -ErrorAction SilentlyContinue
    if(-not $command){return [pscustomobject]@{available=$false;exitCode=$null;output='';error="$FileName is not installed.";timedOut=$false}}
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$command.Source;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $escaped=@($Arguments|ForEach-Object{'"'+($_ -replace '(\\*)"','$1$1\"' -replace '(\\+)$','$1$1')+'"'})
    $start.Arguments=$escaped -join ' '
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start
    try{
        [void]$process.Start();$outputTask=$process.StandardOutput.ReadToEndAsync();$errorTask=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit($TimeoutSeconds*1000)){try{$process.Kill()}catch{};return [pscustomobject]@{available=$false;exitCode=$null;output='';error="$FileName timed out after $TimeoutSeconds seconds.";timedOut=$true}}
        [pscustomobject]@{available=($process.ExitCode -eq 0);exitCode=$process.ExitCode;output=$outputTask.Result;error=$errorTask.Result;timedOut=$false}
    }catch{[pscustomobject]@{available=$false;exitCode=$null;output='';error=$_.Exception.Message;timedOut=$false}}
    finally{$process.Dispose()}
}
