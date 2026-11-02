[CmdletBinding()]
param(
    [ValidateSet('all', 'usb', 'emulator')][string]$Target = 'all',
    [string]$AvdName,
    [switch]$StartEmulator,
    [switch]$StartBackend,
    [ValidateRange(1, 65535)][int]$Port = 8080,
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$sdkCandidates = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)
$localProperties = Join-Path $projectRoot 'hrm_app\android\local.properties'
if (Test-Path -LiteralPath $localProperties) {
    $sdkLine = Get-Content -LiteralPath $localProperties | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
    if ($sdkLine) { $sdkCandidates += ($sdkLine.Substring(8) -replace '\\([\\:])', '$1') }
}
$sdkCandidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
$sdk = $sdkCandidates | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'platform-tools\adb.exe')) } | Select-Object -First 1
if (!$sdk) { throw 'Android SDK not found. Set ANDROID_HOME or hrm_app/android/local.properties.' }
$adb = Join-Path $sdk 'platform-tools\adb.exe'

function Get-AndroidDevices {
    $lines = & $adb devices
    if ($LASTEXITCODE -ne 0) { throw 'adb devices failed.' }
    foreach ($line in $lines) {
        if ($line -match '^(\S+)\s+device$') { $Matches[1] }
        elseif ($line -match '^(\S+)\s+unauthorized$') { Write-Warning "Unlock $($Matches[1]) and accept USB debugging on the phone." }
    }
}

if ($StartEmulator -and $Target -ne 'usb') {
    $allStates = (& $adb devices) -join "`n"
    if ($allStates -notmatch '(?m)^emulator-5554\s') {
        $emulator = Join-Path $sdk 'emulator\emulator.exe'
        if (!(Test-Path -LiteralPath $emulator)) { throw 'Install Android Emulator through Android Studio SDK Manager.' }
        $avds = @(& $emulator -list-avds | Where-Object { $_.Trim() })
        if (!$AvdName) { $AvdName = $avds | Select-Object -First 1 }
        if (!$AvdName -or $AvdName -notin $avds) { throw 'No matching AVD. Create one in Android Studio Device Manager or pass -AvdName.' }
        Write-Host "Starting emulator: $AvdName (emulator-5554)..."
        Start-Process -FilePath $emulator -ArgumentList @('-avd', $AvdName, '-port', '5554') -WindowStyle Hidden | Out-Null
    }
    $deadline = (Get-Date).AddMinutes(3)
    do {
        $devices = @(Get-AndroidDevices)
        $booted = ''
        if ('emulator-5554' -in $devices) { $booted = (& $adb -s emulator-5554 shell getprop sys.boot_completed 2>$null) -join '' }
        if ($booted.Trim() -eq '1') { break }
        if ((Get-Date) -gt $deadline) { throw 'Emulator did not finish booting within 3 minutes.' }
        Start-Sleep -Seconds 2
    } while ($true)
}

function Test-HrmBackend {
    try {
        $response = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/api/auth/google/config" -TimeoutSec 2
        return $response.success -eq $true
    } catch { return $false }
}

if (!(Test-HrmBackend)) {
    if (!$StartBackend) { throw "Backend unavailable at port $Port. Run with -StartBackend or start Spring Boot first." }
    if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
        throw "Port $Port is in use but HRM API is not responding. Check the process using this port."
    }
    $logDir = Join-Path $projectRoot 'target\android-dev'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $backendScript = Join-Path $PSScriptRoot 'start-backend.ps1'
    Write-Host "Starting Spring Boot. Logs: $logDir"
    $backendProcess = Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -PassThru `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $backendScript), '-Port', $Port) `
        -RedirectStandardOutput (Join-Path $logDir 'backend.out.log') -RedirectStandardError (Join-Path $logDir 'backend.err.log')
    $deadline = (Get-Date).AddMinutes(2)
    while (!(Test-HrmBackend)) {
        $backendProcess.Refresh()
        if ($backendProcess.HasExited -or (Get-Date) -gt $deadline) {
            throw "Backend failed to start. Inspect $logDir\backend.out.log and backend.err.log."
        }
        Start-Sleep -Seconds 2
    }
}
Write-Host "Backend ready: http://127.0.0.1:$Port/api"

$devices = @(Get-AndroidDevices | Where-Object {
    $Target -eq 'all' -or ($Target -eq 'emulator' -and $_ -like 'emulator-*') -or ($Target -eq 'usb' -and $_ -notlike 'emulator-*')
})
if ($devices.Count -eq 0) { throw "No authorized Android device for target '$Target'. Connect USB and enable USB debugging, or start an emulator." }
foreach ($serial in $devices) {
    & $adb -s $serial reverse "tcp:$Port" "tcp:$Port" | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Cannot forward port $Port for $serial." }
    Write-Host "Ready: $serial -> http://127.0.0.1:$Port/api"
}
if ($PassThru) { [pscustomobject]@{ Adb = $adb; Devices = $devices; BaseUrl = "http://127.0.0.1:$Port/api" } }
