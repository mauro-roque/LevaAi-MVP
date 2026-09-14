param([switch]$Recompilar)
$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$frontendDir = Join-Path $projectDir 'frontEnd/leva_ai'
$backendDir = Join-Path $projectDir 'backend'
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Instale Node.js 22.13 ou superior.' }
if ($Recompilar -or -not (Test-Path (Join-Path $frontendDir 'build/web/index.html'))) {
  $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
  if (-not $flutterCommand) { throw 'Adicione o Flutter ao PATH para compilar o aplicativo.' }
  # Usa o snapshot do SDK instalado; evita o bootstrap do .bat em pastas com espaços.
  $flutterBin = Split-Path $flutterCommand.Source
  $dartExecutable = Join-Path $flutterBin 'cache/dart-sdk/bin/dart.exe'
  $flutterSnapshot = Join-Path $flutterBin 'cache/flutter_tools.snapshot'
  Push-Location $frontendDir
  try {
    & $dartExecutable $flutterSnapshot pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao obter dependências do Flutter.' }
    & $dartExecutable $flutterSnapshot build web --release
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar a aplicação.' }
  } finally { Pop-Location }
}
Push-Location $backendDir
try {
  Write-Host 'Abra http://127.0.0.1:3000 no navegador. Para encerrar, pressione Ctrl+C.' -ForegroundColor Cyan
  node --env-file-if-exists=.env src/server.mjs
  if ($LASTEXITCODE -ne 0) { throw 'Não foi possível iniciar. Verifique se a porta 3000 já está em uso.' }
} finally { Pop-Location }
