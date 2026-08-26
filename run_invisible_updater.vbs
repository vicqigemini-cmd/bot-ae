Set WshShell = CreateObject("WScript.Shell")
WshShell.Run chr(34) & "apex_silent_updater.bat" & Chr(34), 0
Set WshShell = Nothing
