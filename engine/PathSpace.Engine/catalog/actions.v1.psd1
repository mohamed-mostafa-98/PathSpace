@{
    SchemaVersion = 1
    Actions = @{
        'temp.user' = @{ Title='Remove user temporary files'; Risk='Low'; Reversibility='Reversible'; RequiresElevation=$false; Handler='DirectoryChildren' }
        'temp.windows' = @{ Title='Remove Windows temporary files'; Risk='Medium'; Reversibility='Irreversible'; RequiresElevation=$true; Handler='DirectoryChildren' }
        'recycle.currentUser' = @{ Title='Empty current user Recycle Bin'; Risk='Medium'; Reversibility='Irreversible'; RequiresElevation=$false; Handler='RecycleBin' }
        'cache.npm' = @{ Title='Clear npm download cache'; Risk='Low'; Reversibility='Reversible'; RequiresElevation=$false; Handler='DirectoryChildren' }
        'windows.componentCleanup' = @{ Title='Clean superseded Windows components'; Risk='Medium'; Reversibility='Irreversible'; RequiresElevation=$true; Handler='DismComponentCleanup' }
        'power.hibernate' = @{ Title='Disable hibernation'; Risk='Medium'; Reversibility='Reversible'; RequiresElevation=$true; Handler='DisableHibernation' }
        'volume.optimize' = @{ Title='Optimize volume'; Risk='Low'; Reversibility='Reversible'; RequiresElevation=$true; Handler='OptimizeVolume' }
    }
}
