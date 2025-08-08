# PowerShell script for installing common tools and configuring Windows 11 Pro
# This script is executed during the Packer image building process to customize the base image

# Display startup message to indicate script execution
Write-Host "========================================" -ForegroundColor Green
Write-Host "Starting Windows 11 Pro customization..." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Set execution policy for the current session to allow script execution
# This is necessary for running additional PowerShell scripts during provisioning
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Write-Host "Execution policy set to Bypass for current session" -ForegroundColor Yellow

# Update PowerShell help system (optional but recommended)
# This ensures that Get-Help commands work properly in the final image
Write-Host "Updating PowerShell help system..." -ForegroundColor Yellow
try {
    Update-Help -Force -ErrorAction SilentlyContinue
    Write-Host "PowerShell help system updated successfully" -ForegroundColor Green
}
catch {
    Write-Host "PowerShell help update failed (this is usually not critical): $($_.Exception.Message)" -ForegroundColor Red
}

# Install Chocolatey package manager
# Chocolatey simplifies software installation and management on Windows
Write-Host "Installing Chocolatey package manager..." -ForegroundColor Yellow
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Host "Chocolatey installed successfully" -ForegroundColor Green
}
catch {
    Write-Host "Failed to install Chocolatey: $($_.Exception.Message)" -ForegroundColor Red
}

# Example: Install common development tools using Chocolatey
# Uncomment the tools you want to include in your image
Write-Host "Installing common tools..." -ForegroundColor Yellow

# Text editors and IDEs
# choco install -y notepadplusplus
# choco install -y vscode

# Development tools
# choco install -y git
# choco install -y docker-desktop
# choco install -y nodejs

# System utilities
# choco install -y 7zip
# choco install -y googlechrome
# choco install -y firefox

# Windows Subsystem for Linux (WSL) installation
# This enables Linux environments to run directly on Windows
# Uncomment the following line to enable WSL in your image
# Write-Host "Enabling Windows Subsystem for Linux..." -ForegroundColor Yellow
# Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart

# Windows features configuration
# Enable or disable Windows features as needed for your environment
Write-Host "Configuring Windows features..." -ForegroundColor Yellow

# Example: Enable Hyper-V (uncomment if needed)
# Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart

# Example: Enable IIS (uncomment if needed)
# Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart

# Registry modifications for enterprise settings
# Customize Windows behavior for enterprise environments
Write-Host "Applying enterprise registry settings..." -ForegroundColor Yellow

# Example: Disable Windows Consumer Features (prevents automatic installation of suggested apps)
# New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force
# Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1

# Example: Configure Windows Update settings
# New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force
# Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 0

# Security hardening settings
Write-Host "Applying security hardening settings..." -ForegroundColor Yellow

# Example: Enable Windows Defender real-time protection
# Set-MpPreference -DisableRealtimeMonitoring $false

# Example: Configure User Account Control (UAC) settings
# Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1

# Clean up temporary files and optimize the system
Write-Host "Performing system cleanup..." -ForegroundColor Yellow

# Clear Windows Update cache
# Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue

# Clear temporary files
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Clear Windows logs (optional - uncomment if desired)
# Get-WinEvent -ListLog * | ForEach-Object { Clear-WinEvent -LogName $_.LogName -ErrorAction SilentlyContinue }

# Final system preparation
Write-Host "Preparing system for image capture..." -ForegroundColor Yellow

# Run Windows System File Checker
# sfc /scannow

# Defragment the system drive (for traditional HDDs - skip for SSDs)
# defrag C: /O

# Final message
Write-Host "========================================" -ForegroundColor Green
Write-Host "Windows 11 Pro customization completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Log completion time
Write-Host "Customization completed at: $(Get-Date)" -ForegroundColor Cyan