# Setup Miniconda on Windows
# This script downloads and installs Miniconda3 for Windows

param(
    [string]$InstallPath = "$env:USERPROFILE\miniconda3",
    [switch]$AddToPath = $true,
    [switch]$Force = $false
)

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

Write-Host "Setting up Miniconda on Windows..." -ForegroundColor Green

# Check if Miniconda is already installed
if ((Test-Path $InstallPath) -and -not $Force) {
    Write-Host "Miniconda appears to be already installed at $InstallPath" -ForegroundColor Yellow
    Write-Host "Use -Force parameter to reinstall" -ForegroundColor Yellow
    exit 0
}

# Download URL for latest Miniconda
$MinicondaUrl = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
$InstallerPath = "$env:TEMP\Miniconda3-latest-Windows-x86_64.exe"

Write-Host "Downloading Miniconda installer..." -ForegroundColor Blue
try {
    Invoke-WebRequest -Uri $MinicondaUrl -OutFile $InstallerPath -UseBasicParsing
    Write-Host "Download completed successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to download Miniconda installer: $_"
    exit 1
}

# Install Miniconda silently
Write-Host "Installing Miniconda to $InstallPath..." -ForegroundColor Blue
$InstallArgs = @(
    "/InstallationType=JustMe"
    "/RegisterPython=0"
    "/S"
    "/D=$InstallPath"
)

if ($AddToPath) {
    $InstallArgs += "/AddToPath=1"
} else {
    $InstallArgs += "/AddToPath=0"
}

try {
    Start-Process -FilePath $InstallerPath -ArgumentList $InstallArgs -Wait -NoNewWindow
    Write-Host "Installation completed successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to install Miniconda: $_"
    exit 1
}

# Clean up installer
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue

# Add to PATH for current session if not already done
if ($AddToPath) {
    $CondaPath = "$InstallPath\Scripts"
    if ($env:PATH -notlike "*$CondaPath*") {
        $env:PATH = "$CondaPath;$env:PATH"
        Write-Host "Added Miniconda to PATH for current session" -ForegroundColor Green
    }
}

# Initialize conda
Write-Host "Initializing conda..." -ForegroundColor Blue
try {
    & "$InstallPath\Scripts\conda.exe" init powershell
    Write-Host "Conda initialization completed" -ForegroundColor Green
} catch {
    Write-Warning "Failed to initialize conda. You may need to restart your PowerShell session."
}

# Verify installation
Write-Host "Verifying installation..." -ForegroundColor Blue
try {
    $CondaVersion = & "$InstallPath\Scripts\conda.exe" --version
    Write-Host "✓ $CondaVersion installed successfully" -ForegroundColor Green
    
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Restart your PowerShell session or run: refreshenv" -ForegroundColor White
    Write-Host "2. Test conda with: conda --version" -ForegroundColor White
    Write-Host "3. Create a new environment: conda create -n myenv python=3.9" -ForegroundColor White
    Write-Host "4. Activate environment: conda activate myenv" -ForegroundColor White
    
} catch {
    Write-Error "Installation verification failed. Please check the installation manually."
    exit 1
}

Write-Host "`nMiniconda setup completed successfully!" -ForegroundColor Green