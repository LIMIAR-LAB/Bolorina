param([string]$GodotPath = 'C:/Users/tsmar/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe')
$ErrorActionPreference = 'Stop'
Start-Process -FilePath $GodotPath -ArgumentList @('--path', ('"' + $PSScriptRoot + '"'), 'res://reference_village.tscn')
