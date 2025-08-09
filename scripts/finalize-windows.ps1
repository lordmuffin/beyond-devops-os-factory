# finalize-windows.ps1
# Final Windows Image Preparation Script for Packer
# This script cleans the image, restores security settings, and runs Sysprep
# WARNING: This is an irreversible step - the VM will be generalized and shut down

Write-Host "Starting Windows image finalization process..." -ForegroundColor Green

# ===============================================================================
# Phase 1: System Cleanup
# ===============================================================================
Write-Host "--- Starting System Cleanup ---" -ForegroundColor Yellow

# Clear Chocolatey cache to reduce image size
Write-Host "Clearing Chocolatey cache..." -ForegroundColor Cyan
if (Get-Command choco -ErrorAction SilentlyContinue) {
    choco cache -d -y
    Write-Host "Chocolatey cache cleared successfully." -ForegroundColor Green
} else {
    Write-Host "Chocolatey not found - skipping cache cleanup." -ForegroundColor Yellow
}

# Clear Windows temporary files
Write-Host "Clearing temporary files..." -ForegroundColor Cyan
$TempPaths = @(
    $env:TEMP,
    "$env:windir\Temp",
    "$env:windir\Logs",
    "$env:windir\Panther"
)

foreach ($Path in $TempPaths) {
    if (Test-Path $Path) {
        try {
            Get-ChildItem -Path $Path -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleared: $Path" -ForegroundColor Green
        } catch {
            Write-Host "Warning: Could not clear $Path - $_" -ForegroundColor Yellow
        }
    }
}

# Clear Windows Update cache
Write-Host "Clearing Windows Update cache..." -ForegroundColor Cyan
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
if (Test-Path "$env:windir\SoftwareDistribution\Download") {
    Remove-Item "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
}
Start-Service wuauserv -ErrorAction SilentlyContinue

# Placeholder for additional project-specific cleanup tasks
# Add custom cleanup commands here as needed:
# - Clear application logs
# - Remove build artifacts
# - Clean registry entries
# - Remove temporary certificates

Write-Host "System cleanup completed." -ForegroundColor Green

# ===============================================================================
# Phase 2: Security Restoration
# ===============================================================================
Write-Host "--- Restoring Security Settings ---" -ForegroundColor Yellow

# Re-enable User Account Control (UAC)
Write-Host "Re-enabling User Account Control (UAC)..." -ForegroundColor Cyan
$RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $RegistryPath -Name "EnableLUA" -Value 1 -Force
Write-Host "UAC has been re-enabled for security." -ForegroundColor Green

Write-Host "Security settings restored." -ForegroundColor Green

# ===============================================================================
# Phase 3: Image Generalization with Sysprep
# ===============================================================================
Write-Host "--- Starting Sysprep for Image Generalization ---" -ForegroundColor Red
Write-Host "WARNING: This is the point of no return. The VM will be generalized and shut down." -ForegroundColor Red

# Generate the unattend.xml file for Sysprep
Write-Host "Creating unattend.xml for Sysprep..." -ForegroundColor Cyan
$UnattendXML = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="generalize">
        <component name="Microsoft-Windows-Security-SPP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <SkipRearm>1</SkipRearm>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <CopyProfile>true</CopyProfile>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
            </OOBE>
        </component>
    </settings>
</unattend>
"@

# Save the unattend.xml to the Sysprep directory
$UnattendPath = "C:\Windows\System32\Sysprep\unattend.xml"
try {
    $UnattendXML | Out-File -FilePath $UnattendPath -Encoding utf8 -Force
    Write-Host "Unattend.xml created successfully at $UnattendPath" -ForegroundColor Green
} catch {
    Write-Host "Error creating unattend.xml: $_" -ForegroundColor Red
    exit 1
}

# Critical setting explanation: CopyProfile=true ensures that customizations made to the
# default user profile are copied to new user profiles created after deployment.
# This is essential for maintaining consistent user experience across the organization.

Write-Host "Starting Sysprep generalization process..." -ForegroundColor Red
Write-Host "The system will shut down automatically when complete." -ForegroundColor Red

# Execute Sysprep with the following parameters:
# /generalize - Removes system-specific information and SIDs
# /oobe - Forces the system to run Windows Welcome on next boot
# /shutdown - Shuts down the computer after Sysprep completes
# /unattend - Specifies the answer file to use during generalization
try {
    Start-Process -FilePath "C:\Windows\System32\Sysprep\sysprep.exe" -ArgumentList "/generalize", "/oobe", "/shutdown", "/unattend:$UnattendPath" -Wait -NoNewWindow
    Write-Host "Sysprep completed successfully. System will now shut down." -ForegroundColor Green
} catch {
    Write-Host "Error running Sysprep: $_" -ForegroundColor Red
    exit 1
}

# This script will not reach this point as the system shuts down during Sysprep
Write-Host "Image finalization process completed." -ForegroundColor Green