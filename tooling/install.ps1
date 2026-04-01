# =============================================================================
# QPKI Tool Installation Script for Windows
# Post-Quantum PKI Lab (QLAB)
# =============================================================================

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LabRoot = Split-Path -Parent $ScriptDir

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  QLAB - Post-Quantum PKI Lab"
Write-Host "  Installing QPKI (Post-Quantum PKI) toolkit"
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# Detect architecture
$Arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
Write-Host "Detected: windows / $Arch" -ForegroundColor Green

# =============================================================================
# Check if binary already exists
# =============================================================================

$BinaryPath = Join-Path $LabRoot "bin\qpki.exe"

if (Test-Path $BinaryPath) {
    $InstalledVersion = (& $BinaryPath --version 2>$null) -replace '.*version\s+(\S+).*','$1'

    # Check latest version from GitHub
    try {
        $ReleaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/qpki/qpki/releases/latest" -UseBasicParsing
        $LatestTag = $ReleaseInfo.tag_name -replace "^v", ""
    } catch {
        $LatestTag = ""
    }

    if ($LatestTag -and ($InstalledVersion -ne $LatestTag)) {
        Write-Host ""
        Write-Host "QPKI update available: $InstalledVersion -> $LatestTag" -ForegroundColor Yellow
        Write-Host ""
        $response = Read-Host "  Update now? [Y/n]"
        if ($response -match '^[nN]') {
            Write-Host "  Skipped. Run .\tooling\install.ps1 again to update later."
            Write-Host ""
            exit 0
        }
        Write-Host ""
        Write-Host "  Updating..." -ForegroundColor Cyan
        Remove-Item $BinaryPath
        # Fall through to download
    } else {
        Write-Host ""
        Write-Host "QPKI $InstalledVersion is up to date." -ForegroundColor Green
        Write-Host ""
        exit 0
    }
}

# =============================================================================
# Download pre-built binary from GitHub releases
# =============================================================================

$GithubRepo = "qpki/qpki"
$Version = if ($env:PKI_VERSION) { $env:PKI_VERSION } else { "latest" }

Write-Host ""
Write-Host "Downloading QPKI from GitHub Releases..." -ForegroundColor Cyan
Write-Host ""

# Get version tag
try {
    if ($Version -eq "latest") {
        $ReleaseUrl = "https://api.github.com/repos/$GithubRepo/releases/latest"
        $Release = Invoke-RestMethod -Uri $ReleaseUrl -UseBasicParsing
        $VersionTag = $Release.tag_name
    } else {
        $VersionTag = $Version
    }
} catch {
    Write-Host "Failed to get version from GitHub API" -ForegroundColor Red
    Write-Host $_.Exception.Message
    Show-ManualInstructions
    exit 1
}

if (-not $VersionTag) {
    Write-Host "Failed to get version from GitHub API" -ForegroundColor Red
    Show-ManualInstructions
    exit 1
}

# Remove 'v' prefix for filename (v0.13.0 -> 0.13.0)
$VersionNum = $VersionTag -replace "^v", ""

Write-Host "Version: $VersionTag" -ForegroundColor Green

# Build download URL
$BinaryName = "qpki_${VersionNum}_windows_${Arch}.zip"
$DownloadUrl = "https://github.com/$GithubRepo/releases/download/$VersionTag/$BinaryName"

Write-Host "Downloading: $BinaryName"

# Create bin directory
$BinDir = Join-Path $LabRoot "bin"
if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir | Out-Null
}

# Download and extract
$TempDir = Join-Path $env:TEMP "qpki-install-$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir | Out-Null

try {
    $ZipPath = Join-Path $TempDir $BinaryName

    Write-Host "Downloading..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing

    Write-Host "Extracting..."
    Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force

    # Find and install the binary
    $ExtractedBinary = Get-ChildItem -Path $TempDir -Filter "qpki.exe" -Recurse | Select-Object -First 1

    if ($ExtractedBinary) {
        Move-Item -Path $ExtractedBinary.FullName -Destination $BinaryPath -Force

        Write-Host ""
        Write-Host "==============================================" -ForegroundColor Green
        Write-Host "  QPKI installed successfully!"
        Write-Host "==============================================" -ForegroundColor Green
        Write-Host ""
        & $BinaryPath --version 2>$null
        Write-Host ""
        Write-Host "Binary location: $BinaryPath" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "You can now run the demos (using Git Bash or WSL):"
        Write-Host "  ./journey/00-revelation/demo.sh" -ForegroundColor Cyan
        Write-Host ""
        exit 0
    } else {
        Write-Host "Binary not found in archive" -ForegroundColor Red
    }
} catch {
    Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Cleanup
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# Fallback: Manual instructions
# =============================================================================

function Show-ManualInstructions {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Yellow
    Write-Host "  Download failed - Manual installation required"
    Write-Host "==============================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To use QLAB, you need to build QPKI from source:"
    Write-Host ""
    Write-Host "  1. Clone the QPKI repository:"
    Write-Host "     git clone https://github.com/$GithubRepo.git" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. Build the binary:"
    Write-Host "     cd post-quantum-pki; go build -o ..\post-quantum-pki-lab\bin\qpki.exe .\cmd\qpki" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. Run this script again to verify:"
    Write-Host "     .\tooling\install.ps1" -ForegroundColor Cyan
    Write-Host ""
}

Show-ManualInstructions
exit 1
