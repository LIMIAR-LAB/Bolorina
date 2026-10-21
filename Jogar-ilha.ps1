param([string]$GodotPath = 'C:/Users/tsmar/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe')
# Abre o jogo conectado (Fazenda -> Vila -> Arena). Nao toca no save island_v1.json.
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Informe o executavel Godot 4.7.2 com -GodotPath ou abra jogo_ilha.tscn no editor.'
}
Start-Process -FilePath $GodotPath -ArgumentList @('--path', ('"' + $PSScriptRoot + '"'), 'res://inicio.tscn')
