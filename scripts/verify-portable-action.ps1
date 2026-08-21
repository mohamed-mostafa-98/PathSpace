[CmdletBinding()]
param([string]$ArtifactPath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\PathSpace-win-x64'))
$ErrorActionPreference='Stop'
$artifact=(Resolve-Path $ArtifactPath).Path
$fixture=Join-Path ([IO.Path]::GetTempPath()) ("pathspace-worker-smoke-{0}" -f [guid]::NewGuid().ToString('N'))
$manifestPath=Join-Path $fixture 'manifest.json'
$resultPath=Join-Path $fixture 'result.json'
$previousTemp=$env:TEMP
try{
    New-Item -ItemType Directory -Path $fixture|Out-Null
    [IO.File]::WriteAllBytes((Join-Path $fixture 'disposable.bin'),([byte[]]::new(4096)))|Out-Null
    Add-Type -Path (Join-Path $artifact 'PathSpace.Contracts.dll')
    $targets=[Collections.Generic.List[PathSpace.Contracts.ActionTarget]]::new()
    $targets.Add([PathSpace.Contracts.ActionTarget]::new('temp.user.root',$fixture,$false))
    $now=[DateTimeOffset]::UtcNow
    $unsigned=[PathSpace.Contracts.ActionManifest]::new(1,'action.manifest','temp.user',[guid]::NewGuid().ToString('N'),$now,$now.AddMinutes(5),$targets,'')
    $digest=[PathSpace.Contracts.ActionManifestDigest]::Create($unsigned)
    $manifest=[PathSpace.Contracts.ActionManifest]::new(1,'action.manifest','temp.user',$unsigned.Nonce,$now,$unsigned.ExpiresAt,$targets,$digest)
    [IO.File]::WriteAllText($manifestPath,[Text.Json.JsonSerializer]::Serialize($manifest,$manifest.GetType()))
    $env:TEMP=$fixture
    $process=Start-Process -FilePath (Join-Path $artifact 'worker\PathSpace.Worker.exe') -ArgumentList @('--manifest',$manifestPath,'--result',$resultPath) -Wait -PassThru -NoNewWindow
    if($process.ExitCode -ne 0){throw "Packaged worker exited with code $($process.ExitCode)."}
    $result=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json
    if($result.status -ne 'completed'){throw "Packaged worker returned '$($result.status)'."}
    if(Test-Path -LiteralPath (Join-Path $fixture 'disposable.bin')){throw 'The disposable fixture was not removed.'}
    [pscustomobject]@{WorkerExitCode=$process.ExitCode;Status=$result.status;RecoveredBytes=$result.recoveredBytes;FixtureRemoved=$true}
}
finally{
    $env:TEMP=$previousTemp
    if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force}
}
