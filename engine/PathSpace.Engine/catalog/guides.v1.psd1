@{SchemaVersion=1;Guides=@{
docker=@{Title='Docker and WSL ownership';Warning='Images are rebuildable; named volumes may contain databases. Inspect before pruning.'}
notion=@{Title='Notion local storage';Warning='Confirm all pages are synchronized before resetting local data.'}
claude=@{Title='Claude runtime relocation';Warning='Copy and verify first, retain rollback, then create a junction.'}
pagefile=@{Title='Pagefile guidance';Warning='Never delete pagefile.sys manually; diagnose committed memory and crash-dump needs.'}
hibernation=@{Title='Hibernation';Warning='Reversible, but disabling it removes Hibernate and can affect Fast Startup.'}
volume=@{Title='Native volume optimization';Warning='Use Optimize-Volume; media type determines retrim or defragment behavior.'}
}}
