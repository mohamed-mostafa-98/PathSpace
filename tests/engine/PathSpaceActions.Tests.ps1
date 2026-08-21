$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) '..\engine\PathSpace.Engine\PathSpace.Engine.psd1'
Import-Module (Resolve-Path $modulePath) -Force

Describe 'PathSpace action catalog' {
    It 'rejects an unknown action ID' {
        $message = try { Get-PathSpaceActionPreview -ActionId 'unknown.action' } catch { $_.Exception.Message }
        $message | Should Match 'allow-listed'
    }

    It 'uses exactly the same target identities for preview and dry-run execution' {
        $previousTemp = $env:TEMP
        try {
            $env:TEMP = $TestDrive
            [IO.File]::WriteAllBytes((Join-Path $TestDrive 'disposable.bin'), ([byte[]]::new(12)))
            $preview = Get-PathSpaceActionPreview -ActionId 'temp.user'
            $result = Invoke-PathSpaceAction -ActionId 'temp.user' -DryRun

            @($preview.targets.targetId) -join ',' | Should Be (@($result.targets.targetId) -join ',')
            @($preview.targets.path) -join ',' | Should Be (@($result.targets.path) -join ',')
            $preview.estimatedBytes | Should Be 12
        }
        finally { $env:TEMP = $previousTemp }
    }

    It 'rejects wildcard action parameters' {
        $message = try { Get-PathSpaceActionPreview -ActionId 'volume.optimize' -Parameters @{ DriveLetter='*' } } catch { $_.Exception.Message }
        $message | Should Match 'drive letter'
    }

    It 'executes only confirmed disposable children and reports measured recovery' {
        $previousTemp=$env:TEMP
        try {
            $env:TEMP=$TestDrive
            [IO.File]::WriteAllBytes((Join-Path $TestDrive 'remove.bin'),([byte[]]::new(24)))
            $message=try{Invoke-PathSpaceAction -ActionId 'temp.user'}catch{$_.Exception.Message}
            $message | Should Match 'explicit.*Confirmed'
            [IO.File]::Exists((Join-Path $TestDrive 'remove.bin')) | Should Be $true
            $preview=Get-PathSpaceActionPreview -ActionId 'temp.user'

            $result=Invoke-PathSpaceAction -ActionId 'temp.user' -Confirmed

            [IO.File]::Exists((Join-Path $TestDrive 'remove.bin')) | Should Be $false
            $result.recoveredBytes | Should Not BeLessThan 0
            ($result.messages -join ' ') | Should Match "target measurement changed by $($preview.estimatedBytes) bytes"
            ($result.messages -join ' ') | Should Match 'available disk space changed'
            $result.status | Should Be 'completed'
        } finally {$env:TEMP=$previousTemp}
    }
}
