# Translation Fiesta WinUI - Self-Contained Package Installer
# This script installs the self-contained MSIX package

param(
    [switch]$Force,
    [switch]$RemovePrevious
)

Write-Host "=== Translation Fiesta WinUI Self-Contained Package Installer ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "This script should be run as Administrator for proper package installation."
    $response = Read-Host "Continue anyway? (y/n)"
    if ($response -ne 'y') {
        exit
    }
}

# Get the package path
$packagePath = "bin\Release\net9.0-windows10.0.19041.0\win-x64\AppPackages\TranslationFiesta.WinUI_1.0.0.0_x64_Test\TranslationFiesta.WinUI_1.0.0.0_x64.msix"

if (-not (Test-Path $packagePath)) {
    Write-Error "Package file not found: $packagePath"
    Write-Host "Please run 'dotnet publish' first to generate the package." -ForegroundColor Yellow
    exit 1
}

# Remove previous installation if requested
if ($RemovePrevious) {
    Write-Host "Removing previous installation..." -ForegroundColor Yellow
    try {
        Get-AppxPackage -Name "TranslationFiesta.WinUI" | Remove-AppxPackage -ErrorAction SilentlyContinue
        Write-Host "Previous installation removed." -ForegroundColor Green
    } catch {
        Write-Host "No previous installation found or removal failed." -ForegroundColor Yellow
    }
}

# Install the certificate
Write-Host "Installing package certificate..." -ForegroundColor Yellow
$certPath = "$PSScriptRoot\bin\Release\net9.0-windows10.0.19041.0\win-x64\AppPackages\TranslationFiesta.WinUI_1.0.0.0_x64_Test\TranslationFiesta.WinUI_1.0.0.0_x64.cer"

if (Test-Path $certPath) {
    try {
        # Try LocalMachine first (requires admin)
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPeople", "LocalMachine")
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $store.Add($cert)
        $store.Close()
        Write-Host "Certificate installed to LocalMachine successfully." -ForegroundColor Green
    } catch {
        try {
            # Fallback to CurrentUser if LocalMachine fails
            Write-Host "LocalMachine installation failed, trying CurrentUser..." -ForegroundColor Yellow
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPeople", "CurrentUser")
            $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
            $store.Add($cert)
            $store.Close()
            Write-Host "Certificate installed to CurrentUser successfully." -ForegroundColor Green
            Write-Warning "Note: For production deployment, certificate should be installed to LocalMachine store."
        } catch {
            Write-Warning "Failed to install certificate: $($_.Exception.Message)"
            Write-Host "You may need to manually install the certificate from: $certPath" -ForegroundColor Yellow
            Write-Host "Run certlm.msc (as Administrator) and import to Trusted People store." -ForegroundColor Yellow
        }
    }
} else {
    Write-Warning "Certificate file not found: $certPath"
}

# Install the package
Write-Host "Installing MSIX package..." -ForegroundColor Yellow
try {
    Add-AppxPackage -Path $packagePath -ForceApplicationShutdown -ErrorAction Stop
    Write-Host "Package installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== Installation Complete ===" -ForegroundColor Cyan
    Write-Host "The Translation Fiesta WinUI application is now installed."
    Write-Host "You can find it in the Start Menu or run it from the installed apps."
    Write-Host ""
    Write-Host "Package details:" -ForegroundColor Cyan
    Get-AppxPackage -Name "TranslationFiesta.WinUI" | Select-Object Name, Version, Publisher, Architecture | Format-List
} catch {
    Write-Error "Failed to install package: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Make sure you're running as Administrator"
    Write-Host "2. Check if the certificate is properly installed"
    Write-Host "3. Try installing manually: Add-AppxPackage -Path '$packagePath'"
    Write-Host "4. Check Windows Event Viewer for detailed error information"
    exit 1
}

Write-Host ""
Write-Host "=== Self-Contained Package Information ===" -ForegroundColor Cyan
Write-Host "This package includes:"
Write-Host "- .NET 9.0 Runtime (self-contained)"
Write-Host "- Windows App SDK 1.6.250205002"
Write-Host "- All required dependencies"
Write-Host "- WinUI 3 framework components"
Write-Host ""
Write-Host "Package size: $((Get-Item $packagePath).Length / 1MB) MB" -ForegroundColor Green
