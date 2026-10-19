param([string]$GodotPath = 'C:/Users/tsmar/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe')
# Abre direto o prototipo de combate (cena separada combat_arena.tscn). Nao toca no save do jogo.
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Informe o executavel Godot 4.7.2 com -GodotPath ou abra combat_arena.tscn no editor.'
}
Start-Process -FilePath $GodotPath -ArgumentList @('--path', ('"' + $PSScriptRoot + '"'), 'res://combat_arena.tscn')
