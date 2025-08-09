# prepare-windows.ps1
# Windows System Bootstrap Script for Packer Automation
# This script prepares a fresh Windows image for further automated configuration

Write-Host "Starting Windows system preparation for automation..." -ForegroundColor Green

# Set execution policy to allow script execution during automation
Write-Host "Setting PowerShell execution policy to Bypass..." -ForegroundColor Yellow
Set-ExecutionPolicy Bypass -Scope Process -Force

# Disable User Account Control (UAC) for automation
# WARNING: This is a security reduction and should be re-enabled or managed 
# by group policy in production environments
Write-Host "Disabling UAC for automation..." -ForegroundColor Yellow
$RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $RegistryPath -Name "EnableLUA" -Value 0 -Force
Write-Host "UAC disabled. This change will take effect after reboot." -ForegroundColor Cyan

# Install Chocolatey package manager
Write-Host "Checking for Chocolatey installation..." -ForegroundColor Yellow
$ChocoExists = Get-Command choco -ErrorAction SilentlyContinue

if ($ChocoExists) {
    Write-Host "Chocolatey is already installed." -ForegroundColor Green
} else {
    Write-Host "Installing Chocolatey package manager..." -ForegroundColor Yellow
    try {
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "Chocolatey installation completed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error installing Chocolatey: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Windows system preparation completed successfully." -ForegroundColor Green
Write-Host "Note: A system reboot is required for UAC changes to take effect." -ForegroundColor Cyan
Write-Host "Packer should handle the reboot with a dedicated reboot provisioner." -ForegroundColor Cyan

# Uncomment the following line if manual reboot is needed
# Restart-Computer -Force