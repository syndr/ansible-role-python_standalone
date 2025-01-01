#!/bin/bash
# This script checks for the presence of dependencies and installs them if they are missing.

# List of dependencies
dependencies=("bzip2" "curl" "tar")

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install a package using the appropriate package manager
install_package() {
    package=$1
    if command_exists yum; then
        sudo yum install -y "$package"
    elif command_exists dnf; then
        sudo dnf install -y "$package"
    elif command_exists apt; then
        sudo apt update
        sudo apt install -y "$package"
    else
        echo "Error: No known package manager found. Please install $package manually."
        exit 1
    fi
}

# Iterate over each dependency
for dependency in "${dependencies[@]}"; do
    # Check if the dependency is installed
    if command_exists "$dependency"; then
        echo "$dependency is already installed."
    else
        echo "$dependency is not installed. Attempting to install..."
        # Attempt to install the dependency
        install_package "$dependency"
        # Verify if the installation was successful
        if command_exists "$dependency"; then
            echo "$dependency was successfully installed."
        else
            echo "Error: Failed to install $dependency. Please install it manually."
            exit 1
        fi
    fi
done

