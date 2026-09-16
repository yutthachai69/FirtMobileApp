param(
  [switch]$Live
)

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $workspaceRoot 'backend'
$mobileRoot = Join-Path $workspaceRoot 'mobile'
$flutterPath = 'D:\flutter\bin\flutter.bat'
$pythonPath = (Get-Command python.exe -ErrorAction SilentlyContinue).Source
$webPort = 5000
$webRoot = Join-Path $mobileRoot 'build\web'
$stdoutPath = Join-Path $mobileRoot '.preview_server_stdout.log'
$stderrPath = Join-Path $mobileRoot '.preview_server_stderr.log'

if (-not (Test-Path -LiteralPath $flutterPath)) {
  throw "Flutter SDK not found at $flutterPath"
}
if ([string]::IsNullOrWhiteSpace($pythonPath)) {
  throw 'Python is required to keep the static preview server running.'
}

Write-Host 'Starting RelayContent backend services...'
docker compose -f (Join-Path $backendRoot 'docker-compose.yml') up -d --build
if ($LASTEXITCODE -ne 0) {
  throw 'Docker Compose could not start the backend services.'
}

$dataMode = if ($Live) { 'live' } else { 'demo' }
Write-Host "Building Flutter web preview ($dataMode mode)..."
$previousLocation = Get-Location
Set-Location $mobileRoot
& $flutterPath build web "--dart-define=APP_DATA_MODE=$dataMode" --pwa-strategy=none
$buildExitCode = $LASTEXITCODE
Set-Location $previousLocation
if ($buildExitCode -ne 0) {
  throw 'Flutter web build could not complete.'
}

Write-Host "Starting persistent preview server at http://localhost:$webPort..."
$arguments = @('-m', 'http.server', $webPort, '--directory', $webRoot)
Start-Process `
  -FilePath $pythonPath `
  -ArgumentList $arguments `
  -WorkingDirectory $webRoot `
  -WindowStyle Hidden `
  -RedirectStandardOutput $stdoutPath `
  -RedirectStandardError $stderrPath | Out-Null

Write-Host "Preview: http://localhost:$webPort"
Write-Host "Logs: $stdoutPath and $stderrPath"
