Get-ChildItem translations/*.ts | ForEach-Object { lrelease $_.FullName }
