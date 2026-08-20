$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) '..\engine\PathSpace.Engine\PathSpace.Engine.psd1'
Import-Module (Resolve-Path $modulePath) -Force

Describe 'Invoke-PathSpaceScan' {
    It 'counts fixture bytes, files, directories, and Unicode paths' {
        $unicodeDirectory = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'بيانات')
        [IO.File]::WriteAllBytes((Join-Path $TestDrive 'a.bin'), ([byte[]]::new(10)))
        [IO.File]::WriteAllBytes((Join-Path $unicodeDirectory.FullName 'ملف.bin'), ([byte[]]::new(25)))

        $messages = Invoke-PathSpaceScan -LiteralPath $TestDrive -LargeFileBytes 20 | ForEach-Object { $_ | ConvertFrom-Json }
        $snapshot = $messages | Where-Object kind -eq 'scan.snapshot' | Select-Object -Last 1

        $snapshot.complete | Should Be $true
        $snapshot.cancelled | Should Be $false
        $snapshot.fileCount | Should Be 2
        $snapshot.directoryCount | Should Be 1
        $snapshot.logicalBytes | Should Be 35
        @($snapshot.largeFiles).Count | Should Be 1
        $snapshot.largeFiles[0].logicalBytes | Should Be 25
    }

    It 'does not follow a directory junction' {
        $outside = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'outside')
        $scanRoot = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'root')
        [IO.File]::WriteAllBytes((Join-Path $outside.FullName 'outside.bin'), ([byte[]]::new(100)))
        [IO.File]::WriteAllBytes((Join-Path $scanRoot.FullName 'inside.bin'), ([byte[]]::new(10)))
        $junction = Join-Path $scanRoot.FullName 'junction'
        & cmd.exe /c "mklink /J `"$junction`" `"$($outside.FullName)`"" | Out-Null

        $snapshot = Invoke-PathSpaceScan -LiteralPath $scanRoot.FullName | Select-Object -Last 1 | ConvertFrom-Json

        $snapshot.logicalBytes | Should Be 10
        $snapshot.fileCount | Should Be 1
        @($snapshot.warnings | Where-Object code -eq 'reparse.skipped').Count | Should Be 1
    }

    It 'returns an incomplete cancelled snapshot when cancellation is requested' {
        [IO.File]::WriteAllBytes((Join-Path $TestDrive 'pending.bin'), ([byte[]]::new(50)))
        $cancellationFile = Join-Path $TestDrive 'cancel.requested'
        [IO.File]::WriteAllText($cancellationFile, 'cancel')

        $snapshot = Invoke-PathSpaceScan -LiteralPath $TestDrive -CancellationFile $cancellationFile |
            Select-Object -Last 1 |
            ConvertFrom-Json

        $snapshot.complete | Should Be $false
        $snapshot.cancelled | Should Be $true
    }
}
