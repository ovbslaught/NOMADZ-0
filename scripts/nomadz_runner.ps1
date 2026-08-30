$ErrorActionPreference = "Stop"
$Repo = "ovbslaught/NOMADZ-0"
$InstallDir = if ($env:WORMHOLE_DIR) { "$env:WORMHOLE_DIR\NOMADZ-0\bin" } else { "$env:LOCALAPPDATA\NOMADZ-0" }

if (!(Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
}

Write-Host "==> Checking latest release for $Repo..."
$ReleaseUrl = "https://api.github.com/repos/$Repo/releases/latest"

try {
    $Release = Invoke-RestMethod -Uri $ReleaseUrl -Headers @{"User-Agent"="NOMADZ-PowerShell"}
} catch {
    Write-Warning "Latest tag not found, querying recent releases..."
    $Releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases" -Headers @{"User-Agent"="NOMADZ-PowerShell"}
    $Release = $Releases[0]
}

$Asset = $Release.assets | Where-Object { $_.name -like "*windows*.zip" } | Select-Object -First 1

if (!$Asset) {
    Write-Error "No Windows release archive found."
    exit 1
}

$ZipPath = "$InstallDir\nomadz_windows.zip"
Write-Host "==> Downloading $($Asset.name)..."
Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $ZipPath

Write-Host "==> Extracting to $InstallDir..."
Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
Remove-Item -Force $ZipPath

$ExePath = Get-ChildItem -Path $InstallDir -Filter "*.exe" | Select-Object -First 1

if ($ExePath) {
    Write-Host "==> Launching $($ExePath.FullName)..."
    Start-Process -FilePath $ExePath.FullName -ArgumentList $args
} else {
    Write-Error "Executable not found after extraction."
}
