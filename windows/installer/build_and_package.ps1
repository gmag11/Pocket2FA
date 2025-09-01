Param(
  [switch]$Sign
)

# Script to rename the executable and build the Inno Setup installer.
# Expected location: this script in windows/installer
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Ruta al directorio Release de la build (resuelta desde el directorio del script)
$buildDir = Resolve-Path (Join-Path $scriptDir "..\..\build\windows\x64\runner\Release") -ErrorAction SilentlyContinue
if (-not $buildDir) {
  Write-Error "Build directory not found: ..\..\build\windows\x64\runner\Release"
  exit 1
}
$buildDir = $buildDir.Path

$src = Join-Path $buildDir "twofauth.exe"
$dst = Join-Path $buildDir "2fauth.exe"

if (-not (Test-Path $src)) {
  Write-Error "Source executable not found: $src"
  exit 1
}

# Copy/rename (keeps the original)
Copy-Item -Path $src -Destination $dst -Force
Write-Output "Renamed: $src -> $dst"

# Ruta al compilador Inno Setup y al script .iss
$iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
$iss = Join-Path $scriptDir "TwoFactorAuth.iss"

if (-not (Test-Path $iscc)) {
  Write-Error "ISCC.exe not found at: $iscc. Install Inno Setup or adjust the path."
  exit 1
}
if (-not (Test-Path $iss)) {
  Write-Error ".iss file not found: $iss"
  exit 1
}

# Compile the installer
Write-Output "Running ISCC on $iss"
& $iscc $iss
$exit = $LASTEXITCODE
if ($exit -ne 0) {
  Write-Error "ISCC failed with exit code $exit"
  exit $exit
}

# Optional signing
if ($Sign) {
  $installer = Join-Path $scriptDir "Output\2Fauth_Installer.exe"
  if (Test-Path $installer) {
    Write-Output "Signing installer: $installer"
    & signtool sign /a /tr http://timestamp.digicert.com /td sha256 /fd sha256 $installer
  } else {
    Write-Warning "Installer not found to sign: $installer"
  }
}

Write-Output "Script completed successfully."