$backendEnv = "$PSScriptRoot\backend-env.ps1"
if (Test-Path $backendEnv) {
  & $backendEnv
} else {
  Write-Host "scripts\backend-env.ps1 not found. Using current shell environment."
  Write-Host "Copy scripts\backend-env.example.ps1 to scripts\backend-env.ps1 for local defaults."
}

Push-Location "$PSScriptRoot\..\backend"
try {
  mvn spring-boot:run "-Dspring-boot.run.profiles=local"
} finally {
  Pop-Location
}
