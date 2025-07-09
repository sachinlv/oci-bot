#!/bin/bash

# Setup OCI Config File
# This script creates and configures $HOME/.oci/config with user input

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

# Configuration variables
CONFIG_DIR="$HOME/.oci"
CONFIG_FILE="$CONFIG_DIR/config"
BACKUP_FILE="$CONFIG_DIR/config.backup.$(date +%Y%m%d_%H%M%S)"

# Function to validate OCID format
validate_ocid() {
    local type="$1"
    local ocid="$2"
    
    if [[ ! "$ocid" =~ ^ocid1\.$type\.oc1\. ]]; then
        print_error "Invalid $type OCID format. Should start with 'ocid1.$type.oc1.'"
        return 1
    fi
    return 0
}

# Function to validate region
validate_region() {
    local region="$1"
    # Common OCI regions
    local valid_regions=(
        "us-phoenix-1" "us-ashburn-1" "us-sanjose-1"
        "ca-toronto-1" "ca-montreal-1"
        "eu-frankfurt-1" "eu-zurich-1" "eu-amsterdam-1" "uk-london-1"
        "ap-tokyo-1" "ap-osaka-1" "ap-seoul-1" "ap-mumbai-1" "ap-sydney-1"
        "me-jeddah-1" "sa-saopaulo-1"
    )
    
    for valid_region in "${valid_regions[@]}"; do
        if [[ "$region" == "$valid_region" ]]; then
            return 0
        fi
    done
    
    print_warning "Region '$region' not in common list, but proceeding..."
    return 0
}

# Function to prompt for input with validation
prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local validator="$3"
    local is_required="$4"
    
    while true; do
        read -p "$prompt: " input
        
        if [[ -z "$input" ]] && [[ "$is_required" == "true" ]]; then
            print_error "This field is required."
            continue
        fi
        
        if [[ -n "$input" ]] && [[ -n "$validator" ]]; then
            if ! $validator "$input"; then
                continue
            fi
        fi
        
        eval "$var_name=\"$input\""
        break
    done
}

print_info "OCI Config Setup Script"
print_info "This script will help you create $CONFIG_FILE"
echo ""

# Create .oci directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Backup existing config if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    print_warning "Existing config file found at $CONFIG_FILE"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    print_info "Backup created at $BACKUP_FILE"
    
    read -p "Do you want to continue and overwrite the existing config? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Exiting without changes."
        exit 0
    fi
fi

print_info "Please provide the following information:"
print_info "You can find these values in the OCI Console under Identity & Security > Users"
echo ""

# Collect configuration information
prompt_input "User OCID" "user_ocid" "validate_ocid user" "true"
prompt_input "Tenancy OCID" "tenancy_ocid" "validate_ocid tenancy" "true"
prompt_input "Region (e.g., us-phoenix-1, us-ashburn-1)" "region" "validate_region" "true"

# Key file setup
print_info ""
print_info "API Key Configuration:"
print_info "You can either provide a path to an existing private key file or generate a new one."

read -p "Do you want to generate a new API key pair? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Generate new key pair
    KEY_DIR="$CONFIG_DIR"
    PRIVATE_KEY_FILE="$KEY_DIR/oci_api_key.pem"
    PUBLIC_KEY_FILE="$KEY_DIR/oci_api_key_public.pem"
    
    print_info "Generating new API key pair..."
    
    # Generate private key
    openssl genrsa -out "$PRIVATE_KEY_FILE" 2048
    chmod 400 "$PRIVATE_KEY_FILE"
    
    # Generate public key
    openssl rsa -pubout -in "$PRIVATE_KEY_FILE" -out "$PUBLIC_KEY_FILE"
    
    print_success "API key pair generated:"
    print_info "Private key: $PRIVATE_KEY_FILE"
    print_info "Public key: $PUBLIC_KEY_FILE"
    
    key_file="$PRIVATE_KEY_FILE"
    
    print_warning "IMPORTANT: You need to upload the public key to OCI Console"
    print_info "1. Go to OCI Console > Identity & Security > Users"
    print_info "2. Click on your user"
    print_info "3. Go to API Keys section"
    print_info "4. Click 'Add API Key'"
    print_info "5. Upload the public key file: $PUBLIC_KEY_FILE"
    echo ""
    
    read -p "Press Enter after uploading the public key to continue..."
    
    # Get the key fingerprint
    print_info "Getting key fingerprint..."
    fingerprint=$(openssl rsa -pubout -outform DER -in "$PRIVATE_KEY_FILE" | openssl md5 -c | cut -d' ' -f2)
    
else
    # Use existing key file
    prompt_input "Path to private key file" "key_file" "" "true"
    
    if [[ ! -f "$key_file" ]]; then
        print_error "Private key file not found: $key_file"
        exit 1
    fi
    
    # Get the key fingerprint
    print_info "Getting key fingerprint..."
    fingerprint=$(openssl rsa -pubout -outform DER -in "$key_file" | openssl md5 -c | cut -d' ' -f2)
fi

print_info "Key fingerprint: $fingerprint"

# Optional: Compartment OCID
print_info ""
prompt_input "Compartment OCID (optional, press Enter to skip)" "compartment_ocid" "" "false"

# Create the config file
print_info "Creating OCI config file..."

cat > "$CONFIG_FILE" << EOF
[DEFAULT]
user=$user_ocid
fingerprint=$fingerprint
tenancy=$tenancy_ocid
region=$region
key_file=$key_file
EOF

# Add compartment if provided
if [[ -n "$compartment_ocid" ]]; then
    echo "compartment-id=$compartment_ocid" >> "$CONFIG_FILE"
fi

# Set proper permissions
chmod 600 "$CONFIG_FILE"

print_success "OCI config file created at $CONFIG_FILE"
print_info "Configuration summary:"
echo "  User OCID: $user_ocid"
echo "  Tenancy OCID: $tenancy_ocid"
echo "  Region: $region"
echo "  Key file: $key_file"
echo "  Fingerprint: $fingerprint"
if [[ -n "$compartment_ocid" ]]; then
    echo "  Compartment OCID: $compartment_ocid"
fi

# Test the configuration
print_info ""
print_info "Testing configuration..."

if command -v oci &> /dev/null; then
    if oci iam region list --output table &> /dev/null; then
        print_success "Configuration test passed!"
        print_info "Available regions:"
        oci iam region list --output table
    else
        print_error "Configuration test failed. Please check your settings."
        print_info "Common issues:"
        echo "  - Incorrect OCIDs"
        echo "  - Wrong key file path or permissions"
        echo "  - Public key not uploaded to OCI Console"
        echo "  - Network connectivity issues"
    fi
else
    print_warning "OCI CLI not found. Install it first with: pip install oci-cli"
fi

print_info ""
print_success "Setup completed!"
print_info "Next steps:"
echo "1. Test with: oci iam user get --user-id $user_ocid"
echo "2. List compartments: oci iam compartment list"
echo "3. Configure additional profiles if needed"

if [[ -f "$BACKUP_FILE" ]]; then
    print_info "Backup of previous config saved at: $BACKUP_FILE"
fi