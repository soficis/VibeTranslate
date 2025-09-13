# Translation Fiesta WinUI - Self-Contained Package

This directory contains a self-contained MSIX package for the Translation Fiesta WinUI application that includes all runtime dependencies.

## 📦 Package Contents

The MSIX package includes:
- **.NET 9.0 Runtime** (self-contained)
- **Windows App SDK 1.6.250205002**
- **WinUI 3 Framework** components
- **All required dependencies** for the application
- **Application assets** and resources

## 🚀 Installation

### Method 1: Automated Installation (Recommended)

Run the installation script as Administrator:

```powershell
# Run as Administrator
.\Install-Package.ps1
```

### Method 2: Manual Installation

1. **Install the Certificate** (as Administrator):
   ```powershell
   # Import the certificate to Trusted People store
   $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
   $cert.Import("bin\Release\net9.0-windows10.0.19041.0\win-x64\AppPackages\TranslationFiesta.WinUI_1.0.0.0_x64_Test\TranslationFiesta.WinUI_1.0.0.0_x64.cer")
   $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPeople", "LocalMachine")
   $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
   $store.Add($cert)
   $store.Close()
   ```

2. **Install the Package** (as Administrator):
   ```powershell
   Add-AppxPackage -Path "bin\Release\net9.0-windows10.0.19041.0\win-x64\AppPackages\TranslationFiesta.WinUI_1.0.0.0_x64_Test\TranslationFiesta.WinUI_1.0.0.0_x64.msix"
   ```

## 📋 System Requirements

- **Windows 10 version 1903 (19H1)** or later (build 18362 or later)
- **Windows 11** (all versions supported)
- **Administrator privileges** for installation

## 🔧 Troubleshooting

### Common Issues

1. **"Package certificate not trusted"**
   - Install the certificate manually as shown above
   - Ensure you're running as Administrator

2. **"Package installation failed"**
   - Check Windows Event Viewer (Applications and Services Logs > Microsoft > Windows > AppxPackagingOM)
   - Ensure no older version is installed (uninstall first)

3. **"Access denied"**
   - Always run installation commands as Administrator
   - Check if antivirus software is blocking the installation

### Verification

After installation, verify the package is installed:

```powershell
Get-AppxPackage -Name "TranslationFiesta.WinUI"
```

## 📁 Package Files

```
bin\Release\net9.0-windows10.0.19041.0\win-x64\AppPackages\
├── TranslationFiesta.WinUI_1.0.0.0_x64_Test\
│   ├── TranslationFiesta.WinUI_1.0.0.0_x64.msix    (Main package - ~66MB)
│   ├── TranslationFiesta.WinUI_1.0.0.0_x64.cer     (Code signing certificate)
│   └── AppxManifest.xml                             (Package manifest)
├── Install.ps1                                      (PowerShell installer)
└── Add-AppDevPackage.ps1                            (Development installer)
```

## 🎯 Benefits of Self-Contained Package

- **No external dependencies** - Everything needed is included
- **No .NET runtime installation** required on target machines
- **Isolated installation** - Doesn't affect system-wide .NET installations
- **Easier deployment** - Single file deployment
- **Better compatibility** - Works with different .NET versions on target systems

## 🔄 Updating the Package

To create an updated package:

1. Make your code changes
2. Update the version in `Package.appxmanifest` if needed
3. Run: `dotnet publish /p:PublishProfile=Properties/PublishProfiles/win-x64.pubxml /p:Configuration=Release`
4. The new package will be generated in the same location

## 📞 Support

If you encounter issues:

1. Check the installation logs in Windows Event Viewer
2. Verify system requirements are met
3. Try the manual installation steps
4. Ensure you're running as Administrator

The self-contained package eliminates most COM registration and dependency issues that can occur with unpackaged WinUI applications.
