param([string]$GodotPath = 'C:/Users/tsmar/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe')
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Informe o caminho do Godot com -GodotPath.' }
$previewSave = Join-Path $env:APPDATA 'IlhaDasCinzasPrototype/ilha_interface_preview.json'
$originalSave = Join-Path $env:APPDATA 'IlhaDasCinzasPrototype/ilha_fazenda_v1.json'
if ((-not (Test-Path -LiteralPath $previewSave)) -and (Test-Path -LiteralPath $originalSave)) {
    Copy-Item -LiteralPath $originalSave -Destination $previewSave
}
$beforeSave = $env:ILHA_SAVE
try {
    $env:ILHA_SAVE = 'user://ilha_interface_preview.json'
    Start-Process -FilePath $GodotPath -ArgumentList @('--path', ('"' + $PSScriptRoot + '"'), 'res://jogo_ilha.tscn') -WindowStyle Normal
} finally { $env:ILHA_SAVE = $beforeSave }
