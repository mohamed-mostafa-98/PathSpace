#Requires -RunAsAdministrator
$ErrorActionPreference = 'SilentlyContinue'
Get-PSDrive C,E | Select-Object Name,
    @{Name='UsedGB';Expression={[math]::Round($_.Used/1GB,2)}},
    @{Name='FreeGB';Expression={[math]::Round($_.Free/1GB,2)}}

Get-Item C:\pagefile.sys,C:\hiberfil.sys,C:\swapfile.sys,C:\Windows\MEMORY.DMP -Force |
    Select-Object FullName,@{Name='SizeGB';Expression={[math]::Round($_.Length/1GB,2)}},LastWriteTime

wsl.exe --list --verbose

