param([string]$GodotPath = 'C:/Users/tsmar/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe')
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Informe o executavel Godot 4.7.2 com -GodotPath.'
}
# Abre a comparacao sprite completo x articulado. T alterna o modo.
Start-Process -FilePath $GodotPath -ArgumentList @('--path', ('"' + $PSScriptRoot + '"'), 'res://articulated_comparison.tscn')