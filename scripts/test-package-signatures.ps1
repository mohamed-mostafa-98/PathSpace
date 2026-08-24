[CmdletBinding()]
param(
    [string]$ArtifactPath,
    [Parameter(Mandatory=$true)][string]$ExpectedThumbprint,
    [switch]$AllowUntrusted,
    [switch]$SkipTimestampRequirement
)
$ErrorActionPreference='Stop'
if(-not $ArtifactPath){$ArtifactPath=Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'artifacts\PathSpace-win-x64'}
$expected=$ExpectedThumbprint.Replace(' ','').ToUpperInvariant()
$files=@(Get-ChildItem -LiteralPath $ArtifactPath -Recurse -File | Where-Object {
    $_.Extension -In @('.ps1','.psm1','.psd1','.msi') -or
    ($_.Extension -In @('.exe','.dll') -and $_.Name -like 'PathSpace.*')
})
if(-not $files.Count){throw 'No Authenticode-signable package files were found.'}
$failures=New-Object 'System.Collections.Generic.List[string]'
foreach($file in $files){
    $signature=Get-AuthenticodeSignature -LiteralPath $file.FullName
    $trusted=$signature.Status -eq 'Valid'
    $testValid=$AllowUntrusted -and $signature.Status -eq 'UnknownError' -and $signature.SignerCertificate
    if(-not ($trusted -or $testValid)){$failures.Add("$($file.FullName): signature status $($signature.Status)");continue}
    if(-not $signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint.ToUpperInvariant() -ne $expected){$failures.Add("$($file.FullName): unexpected signer");continue}
    if(-not $SkipTimestampRequirement -and -not $signature.TimeStamperCertificate){$failures.Add("$($file.FullName): timestamp missing")}
}
if($failures.Count){$failures|Write-Error;throw "$($failures.Count) Authenticode verification failure(s)."}
Write-Output "Verified $($files.Count) Authenticode signature(s) for $expected."
