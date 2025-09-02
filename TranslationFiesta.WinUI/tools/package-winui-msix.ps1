param(
    [Parameter(Mandatory=$true)]
    [string]$AppExecutablePath,
    [Parameter(Mandatory=$false)]
    [string]$OutputMsix = "./TranslationFiesta.msix",
    [Parameter(Mandatory=$false)]
    [string]$Publisher = "CN=LocalDev",
    [Parameter(Mandatory=$false)]
    [string]$CertificatePfx = "",
    [Parameter(Mandatory=$false)]
    [string]$CertPassword = ""
)

Write-Host "Packaging WinUI app: $AppExecutablePath -> $OutputMsix"

# Ensure makeappx and signtool are available (from Windows SDK)
$makeappx = "makeappx.exe"
$signTool = "signtool.exe"

$packageDir = Join-Path (Split-Path -Parent $OutputMsix) "msixpkg"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $packageDir
New-Item -ItemType Directory -Path $packageDir | Out-Null

Copy-Item -Path $AppExecutablePath -Destination $packageDir
Copy-Item -Path "Package.appxmanifest" -Destination $packageDir

$makeCmd = "$makeappx pack /d `"$packageDir`" /p `"$OutputMsix`""
Write-Host $makeCmd
Invoke-Expression $makeCmd

if ($CertificatePfx -ne "") {
    $signCmd = "$signTool sign /fd SHA256 /a /f `"$CertificatePfx`" /p `"$CertPassword`" `"$OutputMsix`""
    Write-Host $signCmd
    Invoke-Expression $signCmd
} else {
    Write-Host "MSIX created unsigned: $OutputMsix. Use SignTool to sign for distribution."
}
