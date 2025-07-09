#!/bin/bash

# Miniconda Setup Script
# This script downloads and installs miniconda if not already present

set -e

MINICONDA_VERSION="latest"
MINICONDA_DIR="$HOME/miniconda3"

# Detect OS and architecture
OS=$(uname -s)
ARCH=$(uname -m)

if [[ "$OS" == "Darwin" ]]; then
    if [[ "$ARCH" == "arm64" ]]; then
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh"
    else
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"
    fi
elif [[ "$OS" == "Linux" ]]; then
    if [[ "$ARCH" == "x86_64" ]]; then
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    elif [[ "$ARCH" == "aarch64" ]]; then
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh"
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
else
    echo "Unsupported operating system: $OS"
    exit 1
fi

# Check if miniconda is already installed
if [[ -d "$MINICONDA_DIR" ]]; then
    echo "Miniconda already installed at $MINICONDA_DIR"
    echo "To reinstall, remove the directory first: rm -rf $MINICONDA_DIR"
    exit 0
fi

# Download and install miniconda
echo "Downloading Miniconda from $MINICONDA_URL"
wget -O /tmp/miniconda.sh "$MINICONDA_URL"

echo "Installing Miniconda to $MINICONDA_DIR"
bash /tmp/miniconda.sh -b -p "$MINICONDA_DIR"

# Initialize conda
echo "Initializing conda..."
"$MINICONDA_DIR/bin/conda" init

# Clean up
rm /tmp/miniconda.sh

echo "Miniconda installation completed!"
echo "Please restart your terminal or run 'source ~/.bashrc' (or ~/.zshrc) to use conda"
echo "Verify installation with: conda --version"