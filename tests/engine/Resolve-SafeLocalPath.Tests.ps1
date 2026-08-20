$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) '..\engine\PathSpace.Engine\PathSpace.Engine.psd1'
Import-Module (Resolve-Path $modulePath) -Force

Describe 'Resolve-SafeLocalPath' {
    InModuleScope PathSpace.Engine {
        It 'normalizes a local directory' {
            $result = Resolve-SafeLocalPath -LiteralPath $TestDrive
            $result.FullName | Should Be ([IO.Path]::GetFullPath($TestDrive))
        }

        It 'rejects a UNC path before checking whether it exists' {
            $message = try { Resolve-SafeLocalPath -LiteralPath '\\server\share' } catch { $_.Exception.Message }
            $message | Should Match 'network'
        }

        It 'rejects a missing local directory' {
            $message = try { Resolve-SafeLocalPath -LiteralPath (Join-Path $TestDrive 'missing') } catch { $_.Exception.Message }
            $message | Should Match 'does not exist'
        }

        It 'rejects a file when a directory is required' {
            $file = Join-Path $TestDrive 'file.txt'
            Set-Content -LiteralPath $file -Value 'fixture'
            $message = try { Resolve-SafeLocalPath -LiteralPath $file } catch { $_.Exception.Message }
            $message | Should Match 'directory'
        }
    }
}
