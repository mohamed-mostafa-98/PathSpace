$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) '..\engine\PathSpace.Engine\PathSpace.Engine.psd1'
Import-Module (Resolve-Path $modulePath) -Force
$fixtureRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'fixtures\legacy'
$global:PathSpaceDockerFixture = Get-Content (Join-Path $fixtureRoot 'docker-system-df.txt') -Raw
$global:PathSpaceWslFixture = Get-Content (Join-Path $fixtureRoot 'wsl-list-verbose.txt') -Raw

Describe 'PathSpace application diagnostics' {
    InModuleScope PathSpace.Engine {
        It 'parses Docker reclaimable images and protects named-volume evidence' {
            $result = ConvertFrom-DockerSystemDf -Text $global:PathSpaceDockerFixture
            $result.imageReclaimableBytes | Should BeGreaterThan 15GB
            $result.volumeReclaimableBytes | Should BeGreaterThan 4GB
            $result.hasVolumes | Should Be $true
        }
        It 'parses Ubuntu and docker-desktop WSL ownership' {
            $result = @(ConvertFrom-WslList -Text $global:PathSpaceWslFixture)
            @($result.name) -join ',' | Should Be 'Ubuntu,docker-desktop'
            $result[0].version | Should Be 2
        }
    }
    It 'returns unavailable diagnostics instead of throwing when commands are unavailable' {
        $result = Get-PathSpaceAppDiagnostic -FixtureOutputs @{ wsl=$null; docker=$null }
        ($result | Where-Object id -eq 'wsl').available | Should Be $false
        ($result | Where-Object id -eq 'docker').available | Should Be $false
    }
    It 'writes diagnostics through the Windows PowerShell CLI to an absolute local path' {
        $cli = (Resolve-Path (Join-Path (Split-Path $PSScriptRoot -Parent) '..\cli\pathspace.ps1')).Path
        $output = Join-Path $TestDrive 'diagnostics.jsonl'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cli diagnose -OutputPath $output
        $LASTEXITCODE | Should Be 0
        [IO.File]::Exists($output) | Should Be $true
        (Get-Content -LiteralPath $output -TotalCount 1 | ConvertFrom-Json).kind | Should Be 'app.diagnostic'
    }
}
