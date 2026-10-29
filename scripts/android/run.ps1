[CmdletBinding()]
param(
    [ValidateSet('all', 'usb', 'emulator')][string]$Target = 'all',
    [string]$AvdName
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$setup = & (Join-Path $PSScriptRoot 'prepare.ps1') -Target $Target -AvdName $AvdName -StartEmulator -StartBackend -PassThru
Push-Location -LiteralPath (Join-Path $projectRoot 'hrm_app')
try {
    if ($Target -ne 'all') {
        & flutter run -d $setup.Devices[0] "--dart-define=API_BASE_URL=$($setup.BaseUrl)"
        if ($LASTEXITCODE -ne 0) { throw 'flutter run failed.' }
    } else {
        # Build once, install the same APK on every connected Android device.
        & flutter build apk --debug "--dart-define=API_BASE_URL=$($setup.BaseUrl)"
        if ($LASTEXITCODE -ne 0) { throw 'Android build failed.' }
        $apk = Join-Path $projectRoot 'hrm_app\build\app\outputs\flutter-apk\app-debug.apk'
        foreach ($serial in $setup.Devices) {
            & $setup.Adb -s $serial install -r $apk
            if ($LASTEXITCODE -ne 0) { throw "APK installation failed: $serial" }
            & $setup.Adb -s $serial shell am start -n com.example.hrm_app/.MainActivity
            if ($LASTEXITCODE -ne 0) { throw "App launch failed: $serial" }
        }
        Write-Host 'App running on all connected Android devices. Use the VS Code compound launch for hot reload on both.'
    }
} finally { Pop-Location }
