$scriptPath=Join-Path (Split-Path $PSScriptRoot -Parent) '..\legacy-toolkit\07-move-claude-runtime-to-e.ps1'
$scriptPath=(Resolve-Path $scriptPath).Path
Describe 'Claude runtime relocation rollback' {
    It 'previews without changing the source' {
        $root=Join-Path $TestDrive 'preview-fixture';$source=Join-Path $root 'vm_bundles';$target=Join-Path $root 'target'
        New-Item -ItemType Directory -Path $source -Force|Out-Null
        [IO.File]::WriteAllBytes((Join-Path $source 'runtime.bin'),([byte[]]::new(16)))
        $result=& $scriptPath -Source $source -TargetRoot $target -SkipVolumeValidation -SkipClaudeStop -WhatIf
        $result.Status|Should Be 'preview'
        (Test-Path -LiteralPath (Join-Path $source 'runtime.bin'))|Should Be $true
        (Test-Path -LiteralPath "$source.c-backup")|Should Be $false
    }
    It 'rejects overlapping source and target paths' {
        $source=Join-Path $TestDrive 'overlap';New-Item -ItemType Directory -Path $source -Force|Out-Null
        {& $scriptPath -Source $source -TargetRoot (Join-Path $source 'target') -SkipVolumeValidation -SkipClaudeStop -Confirm:$false}|Should Throw 'Source and target paths must not overlap.'
    }
    It 'stages through a verified junction and restores the retained backup' {
        $root=Join-Path $TestDrive 'claude-fixture'
        $source=Join-Path $root 'package\vm_bundles'
        $targetRoot=Join-Path $root 'target'
        New-Item -ItemType Directory -Path $source -Force|Out-Null
        [IO.File]::WriteAllBytes((Join-Path $source 'runtime.bin'),([byte[]]::new(128)))
        $staged=& $scriptPath -Source $source -TargetRoot $targetRoot -SkipVolumeValidation -SkipClaudeStop -Confirm:$false
        $junction=Get-Item -LiteralPath $source -Force
        $staged.Status|Should Be 'staged'
        $junction.LinkType|Should Be 'Junction'
        (Test-Path -LiteralPath "$source.c-backup\runtime.bin")|Should Be $true
        $rolledBack=& $scriptPath -Source $source -TargetRoot $targetRoot -SkipVolumeValidation -SkipClaudeStop -Rollback -Confirm:$false
        $rolledBack.Status|Should Be 'rolledBack'
        (Get-Item -LiteralPath $source -Force).LinkType|Should Not Be 'Junction'
        (Test-Path -LiteralPath (Join-Path $source 'runtime.bin'))|Should Be $true
        (Test-Path -LiteralPath "$source.c-backup")|Should Be $false
    }
}
