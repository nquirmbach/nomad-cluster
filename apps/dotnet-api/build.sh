#!/bin/bash
set -e

# Build the .NET application for Linux
dotnet publish -c Release

# Create a directory for the release
mkdir -p release

# Copy the published files to the release directory
cp -r bin/Release/net8.0/linux-x64/publish/* release/

# Make the executable file executable
chmod +x release/dotnet-api

echo "Build completed successfully. Executable is in the release directory."
