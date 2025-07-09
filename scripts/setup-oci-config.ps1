# Setup OCI Config File for Windows PowerShell
# This script creates and configures $HOME/.oci/config with user input

param(
    [switch]$Force = $false
)

# Function to write colored output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to validate OCID format
function Test-OCID {
    param(
        [string]$OCID,
        [string]$Type
    )
    
    if ($OCID -notmatch "^ocid1\.$Type\.oc1\.") {
        Write-Error "Invalid $Type OCID format. Should start with 'ocid1.$Type.oc1.'"
        return $false
    }
    return $true
}

# Function to validate region
function Test-Region {
    param([string]$Region)
    
    $ValidRegions = @(
        "us-phoenix-1", "us-ashburn-1", "us-sanjose-1",
        "ca-toronto-1", "ca-montreal-1",
        "eu-frankfurt-1", "eu-zurich-1", "eu-amsterdam-1", "uk-london-1",
        "ap-tokyo-1", "ap-osaka-1", "ap-seoul-1", "ap-mumbai-1", "ap-sydney-1",
        "me-jeddah-1", "sa-saopaulo-1"
    )
    
    if ($Region -in $ValidRegions) {
        return $true
    }
    
    Write-Warning "Region '$Region' not in common list, but proceeding..."
    return $true
}

# Function to prompt for input with validation
function Get-ValidatedInput {
    param(
        [string]$Prompt,
        [scriptblock]$Validator,
        [bool]$Required = $true
    )
    
    do {
        $input = Read-Host -Prompt $Prompt
        
        if ([string]::IsNullOrWhiteSpace($input) -and $Required) {
            Write-Error "This field is required."
            continue
        }
        
        if (![string]::IsNullOrWhiteSpace($input) -and $Validator) {
            if (-not (& $Validator $input)) {
                continue
            }
        }
        
        return $input
    } while ($true)
}

# Function to generate RSA key pair
function New-RSAKeyPair {
    param(
        [string]$PrivateKeyPath,
        [string]$PublicKeyPath
    )
    
    try {
        # Check if OpenSSL is available
        if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
            Write-Error "OpenSSL is required but not found. Please install OpenSSL first."
            Write-Info "You can install OpenSSL via:"
            Write-Info "- Chocolatey: choco install openssl"
            Write-Info "- Git for Windows (includes OpenSSL)"
            Write-Info "- Download from: https://slproweb.com/products/Win32OpenSSL.html"
            return $false
        }
        
        # Generate private key
        $result = & openssl genrsa -out $PrivateKeyPath 2048 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to generate private key: $result"
            return $false
        }
        
        # Generate public key
        $result = & openssl rsa -pubout -in $PrivateKeyPath -out $PublicKeyPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to generate public key: $result"
            return $false
        }
        
        return $true
    }
    catch {
        Write-Error "Error generating key pair: $_"
        return $false
    }
}

# Function to get key fingerprint
function Get-KeyFingerprint {
    param([string]$PrivateKeyPath)
    
    try {
        $result = & openssl rsa -pubout -outform DER -in $PrivateKeyPath | openssl md5 -c 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to get key fingerprint: $result"
            return $null
        }
        
        # Extract fingerprint from output
        $fingerprint = ($result -split ' ')[-1]
        return $fingerprint
    }
    catch {
        Write-Error "Error getting key fingerprint: $_"
        return $null
    }
}

# Main script
Write-Info "OCI Config Setup Script for Windows"
Write-Info "This script will help you create $env:USERPROFILE\.oci\config"
Write-Host ""

# Configuration variables
$ConfigDir = "$env:USERPROFILE\.oci"
$ConfigFile = "$ConfigDir\config"
$BackupFile = "$ConfigDir\config.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Create .oci directory if it doesn't exist
if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

# Backup existing config if it exists
if (Test-Path $ConfigFile) {
    Write-Warning "Existing config file found at $ConfigFile"
    
    if (-not $Force) {
        $response = Read-Host "Do you want to continue and overwrite the existing config? (y/N)"
        if ($response -notmatch '^[Yy]$') {
            Write-Info "Exiting without changes."
            exit 0
        }
    }
    
    Copy-Item $ConfigFile $BackupFile
    Write-Info "Backup created at $BackupFile"
}

Write-Info "Please provide the following information:"
Write-Info "You can find these values in the OCI Console under Identity & Security > Users"
Write-Host ""

# Collect configuration information
$UserOCID = Get-ValidatedInput -Prompt "User OCID" -Validator { param($ocid) Test-OCID $ocid "user" }
$TenancyOCID = Get-ValidatedInput -Prompt "Tenancy OCID" -Validator { param($ocid) Test-OCID $ocid "tenancy" }
$Region = Get-ValidatedInput -Prompt "Region (e.g., us-phoenix-1, us-ashburn-1)" -Validator { param($region) Test-Region $region }

# Key file setup
Write-Host ""
Write-Info "API Key Configuration:"
Write-Info "You can either provide a path to an existing private key file or generate a new one."

$GenerateNew = Read-Host "Do you want to generate a new API key pair? (y/N)"

if ($GenerateNew -match '^[Yy]$') {
    # Generate new key pair
    $PrivateKeyFile = "$ConfigDir\oci_api_key.pem"
    $PublicKeyFile = "$ConfigDir\oci_api_key_public.pem"
    
    Write-Info "Generating new API key pair..."
    
    if (New-RSAKeyPair -PrivateKeyPath $PrivateKeyFile -PublicKeyPath $PublicKeyFile) {
        Write-Success "API key pair generated:"
        Write-Info "Private key: $PrivateKeyFile"
        Write-Info "Public key: $PublicKeyFile"
        
        $KeyFile = $PrivateKeyFile
        
        Write-Warning "IMPORTANT: You need to upload the public key to OCI Console"
        Write-Info "1. Go to OCI Console > Identity & Security > Users"
        Write-Info "2. Click on your user"
        Write-Info "3. Go to API Keys section"
        Write-Info "4. Click 'Add API Key'"
        Write-Info "5. Upload the public key file: $PublicKeyFile"
        Write-Host ""
        
        Read-Host "Press Enter after uploading the public key to continue"
    }
    else {
        Write-Error "Failed to generate key pair. Exiting."
        exit 1
    }
}
else {
    # Use existing key file
    do {
        $KeyFile = Read-Host "Path to private key file"
        if (-not (Test-Path $KeyFile)) {
            Write-Error "Private key file not found: $KeyFile"
        }
    } while (-not (Test-Path $KeyFile))
}

# Get the key fingerprint
Write-Info "Getting key fingerprint..."
$Fingerprint = Get-KeyFingerprint -PrivateKeyPath $KeyFile

if (-not $Fingerprint) {
    Write-Error "Failed to get key fingerprint. Exiting."
    exit 1
}

Write-Info "Key fingerprint: $Fingerprint"

# Optional: Compartment OCID
Write-Host ""
$CompartmentOCID = Get-ValidatedInput -Prompt "Compartment OCID (optional, press Enter to skip)" -Required $false

# Create the config file
Write-Info "Creating OCI config file..."

$ConfigContent = @"
[DEFAULT]
user=$UserOCID
fingerprint=$Fingerprint
tenancy=$TenancyOCID
region=$Region
key_file=$($KeyFile -replace '\\', '/')
"@

# Add compartment if provided
if (-not [string]::IsNullOrWhiteSpace($CompartmentOCID)) {
    $ConfigContent += "`ncompartment-id=$CompartmentOCID"
}

# Write config file
$ConfigContent | Out-File -FilePath $ConfigFile -Encoding UTF8

Write-Success "OCI config file created at $ConfigFile"
Write-Info "Configuration summary:"
Write-Host "  User OCID: $UserOCID"
Write-Host "  Tenancy OCID: $TenancyOCID"
Write-Host "  Region: $Region"
Write-Host "  Key file: $KeyFile"
Write-Host "  Fingerprint: $Fingerprint"
if (-not [string]::IsNullOrWhiteSpace($CompartmentOCID)) {
    Write-Host "  Compartment OCID: $CompartmentOCID"
}

# Test the configuration
Write-Host ""
Write-Info "Testing configuration..."

if (Get-Command oci -ErrorAction SilentlyContinue) {
    try {
        $testResult = & oci iam region list --output table 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Configuration test passed!"
            Write-Info "Available regions:"
            Write-Host $testResult
        }
        else {
            Write-Error "Configuration test failed: $testResult"
            Write-Info "Common issues:"
            Write-Host "  - Incorrect OCIDs"
            Write-Host "  - Wrong key file path or permissions"
            Write-Host "  - Public key not uploaded to OCI Console"
            Write-Host "  - Network connectivity issues"
        }
    }
    catch {
        Write-Error "Configuration test failed: $_"
    }
}
else {
    Write-Warning "OCI CLI not found. Install it first with: pip install oci-cli"
}

Write-Host ""
Write-Success "Setup completed!"
Write-Info "Next steps:"
Write-Host "1. Test with: oci iam user get --user-id $UserOCID"
Write-Host "2. List compartments: oci iam compartment list"
Write-Host "3. Configure additional profiles if needed"

if (Test-Path $BackupFile) {
    Write-Info "Backup of previous config saved at: $BackupFile"
}

# Create environment script
$EnvScript = "$ConfigDir\oci-env.ps1"
$EnvContent = @"
# OCI CLI Environment Setup for PowerShell
# Run this script to set up OCI environment variables

`$env:OCI_CLI_AUTH = "api_key"
`$env:OCI_CONFIG_FILE = "$ConfigFile"
`$env:OCI_CONFIG_PROFILE = "DEFAULT"

# Optional: Set default compartment OCID
# `$env:OCI_CLI_COMPARTMENT_ID = "ocid1.compartment.oc1....."

Write-Host "OCI CLI environment variables set:" -ForegroundColor Green
Write-Host "  OCI_CONFIG_FILE: `$env:OCI_CONFIG_FILE"
Write-Host "  OCI_CONFIG_PROFILE: `$env:OCI_CONFIG_PROFILE"
Write-Host "  OCI_CLI_AUTH: `$env:OCI_CLI_AUTH"
"@

$EnvContent | Out-File -FilePath $EnvScript -Encoding UTF8

Write-Info "Environment script created at: $EnvScript"
Write-Info "Run '. $EnvScript' to set up environment variables"