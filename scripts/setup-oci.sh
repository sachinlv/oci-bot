#!/bin/bash

# Setup OCI CLI on macOS or Linux
# This script installs OCI CLI and helps with initial configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS
OS=$(uname -s)
ARCH=$(uname -m)

print_info "Detected OS: $OS ($ARCH)"

# Check if OCI CLI is already installed
if command -v oci &> /dev/null; then
    print_warning "OCI CLI is already installed"
    oci --version
    read -p "Do you want to reinstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipping installation. Proceeding to configuration check..."
        exit 0
    fi
fi

# Install OCI CLI based on OS
print_info "Installing OCI CLI..."

case $OS in
    "Darwin")
        # macOS
        if command -v brew &> /dev/null; then
            print_info "Installing via Homebrew..."
            brew install oci-cli
        else
            print_info "Homebrew not found. Installing via pip..."
            if command -v pip3 &> /dev/null; then
                pip3 install oci-cli
            elif command -v pip &> /dev/null; then
                pip install oci-cli
            else
                print_error "Neither pip nor pip3 found. Please install Python first."
                exit 1
            fi
        fi
        ;;
    "Linux")
        # Linux
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            print_info "Installing via apt (Debian/Ubuntu)..."
            sudo apt-get update
            sudo apt-get install -y python3-pip
            pip3 install oci-cli
        elif command -v yum &> /dev/null; then
            # RHEL/CentOS
            print_info "Installing via yum (RHEL/CentOS)..."
            sudo yum install -y python3-pip
            pip3 install oci-cli
        elif command -v dnf &> /dev/null; then
            # Fedora
            print_info "Installing via dnf (Fedora)..."
            sudo dnf install -y python3-pip
            pip3 install oci-cli
        else
            print_info "Package manager not detected. Installing via pip..."
            if command -v pip3 &> /dev/null; then
                pip3 install oci-cli
            elif command -v pip &> /dev/null; then
                pip install oci-cli
            else
                print_error "Neither pip nor pip3 found. Please install Python first."
                exit 1
            fi
        fi
        ;;
    *)
        print_error "Unsupported OS: $OS"
        exit 1
        ;;
esac

# Verify installation
print_info "Verifying OCI CLI installation..."
if command -v oci &> /dev/null; then
    print_success "OCI CLI installed successfully"
    oci --version
else
    print_error "OCI CLI installation failed"
    exit 1
fi

# Check if config exists
CONFIG_DIR="$HOME/.oci"
CONFIG_FILE="$CONFIG_DIR/config"

if [ -f "$CONFIG_FILE" ]; then
    print_success "OCI config file already exists at $CONFIG_FILE"
    print_info "Current configuration profiles:"
    oci iam region list --output table 2>/dev/null || print_warning "Unable to list regions. Please check your configuration."
else
    print_info "OCI config file not found. Starting configuration setup..."
    
    print_info "You'll need the following information:"
    echo "  - User OCID"
    echo "  - Tenancy OCID"
    echo "  - Region (e.g., us-phoenix-1, us-ashburn-1)"
    echo "  - API Key (or path to private key file)"
    echo ""
    
    read -p "Do you want to configure OCI CLI now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Running OCI CLI configuration setup..."
        oci setup config
        
        # Test configuration
        print_info "Testing configuration..."
        if oci iam region list --output table &> /dev/null; then
            print_success "Configuration test passed!"
        else
            print_warning "Configuration test failed. Please check your settings."
        fi
    else
        print_info "Skipping configuration. You can run 'oci setup config' later."
    fi
fi

# Create or update environment script
ENV_SCRIPT="$HOME/.oci/oci-env.sh"
mkdir -p "$HOME/.oci"

cat > "$ENV_SCRIPT" << 'EOF'
#!/bin/bash
# OCI CLI Environment Setup
# Source this file to set up OCI environment variables

export OCI_CLI_AUTH=api_key
export OCI_CONFIG_FILE="$HOME/.oci/config"
export OCI_CONFIG_PROFILE=DEFAULT

# Optional: Set default compartment OCID
# export OCI_CLI_COMPARTMENT_ID="ocid1.compartment.oc1....."

echo "OCI CLI environment variables set:"
echo "  OCI_CONFIG_FILE: $OCI_CONFIG_FILE"
echo "  OCI_CONFIG_PROFILE: $OCI_CONFIG_PROFILE"
echo "  OCI_CLI_AUTH: $OCI_CLI_AUTH"
EOF

chmod +x "$ENV_SCRIPT"

print_success "OCI CLI setup completed!"
print_info "Next steps:"
echo "1. Source the environment script: source $ENV_SCRIPT"
echo "2. Test your configuration: oci iam user get --user-id <your-user-ocid>"
echo "3. List available regions: oci iam region list"
echo "4. Configure additional profiles if needed: oci setup config"
echo ""
print_info "For more information, visit: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm"