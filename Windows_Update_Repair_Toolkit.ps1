#requires -Version 5.1
<#
.SYNOPSIS
    Windows Update Diagnostic Toolkit.

.DESCRIPTION
    Menu-driven PowerShell toolkit for L1/L2 IT support Windows Update checks.
    Collects service status, pending reboot indicators, disk space, installed
    hotfixes, update history, BITS job state, and update-related event logs.

.NOTES
    Author: Dewald Pretorius / Dtech IT Solutions
    Version: 1.0.2
    PowerShell: Windows PowerShell 5.1+
    Platform: Windows 10 / Windows 11
    This version is diagnostic-only.
#>

[CmdletBinding()]
param(
    [switch]$RunAll,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '1.0.2'
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-ReportFolder {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $Path = Join-Path $desktop 'Windows_Update_Reports'
    }
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    return $Path
}

$ReportRoot = Initialize-ReportFolder -Path $OutputPath
$LogFile = Join-Path $ReportRoot "WindowsUpdateCheck_$RunStamp.log"

function Write-Log {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')] [string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    switch ($Level) {
        'WARN'    { Write-Host $Message -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
        'SUCCESS' { Write-Host $Message -ForegroundColor Green }
        default   { Write-Host $Message }
    }
}

function Pause-Menu {
    Write-Host
    [void](Read-Host 'Press Enter to return to the menu')
}

function Show-Header {
    Clear-Host
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '   WINDOWS UPDATE DIAGNOSTIC TOOLKIT' -ForegroundColor Cyan
    Write-Host "   Version $ScriptVersion" -ForegroundColor DarkCyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ("   Computer : {0}" -f $env:COMPUTERNAME)
    Write-Host ("   User     : {0}\{1}" -f $env:USERDOMAIN, $env:USERNAME)
    Write-Host ("   Admin    : {0}" -f (Test-IsAdministrator))
    Write-Host ("   Reports  : {0}" -f $ReportRoot)
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host
}

function New-Check {
    param(
        [Parameter(Mandatory)] [string]$Category,
        [Parameter(Mandatory)] [string]$Name,
        [ValidateSet('OK','Warning','Critical','Info')] [string]$Status = 'Info',
        [string]$Value = '',
        [string]$Recommendation = ''
    )
    [PSCustomObject]@{
        Category       = $Category
        Name           = $Name
        Status         = $Status
        Value          = $Value
        Recommendation = $Recommendation
    }
}

function Export-ToolkitReport {
    param(
        [Parameter(Mandatory)] [object[]]$Checks,
        [Parameter(Mandatory)] [string]$ReportName,
        [switch]$OpenReport
    )
    $safeName = $ReportName -replace '[^\w\-]', '_'
    $csvPath = Join-Path $ReportRoot "$safeName`_$RunStamp.csv"
    $jsonPath = Join-Path $ReportRoot "$safeName`_$RunStamp.json"
    $htmlPath = Join-Path $ReportRoot "$safeName`_$RunStamp.html"
    $Checks | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    $Checks | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8
    $htmlHeader = @"
<h1>$ReportName</h1>
<p><b>Computer:</b> $env:COMPUTERNAME<br><b>User:</b> $env:USERDOMAIN\$env:USERNAME<br><b>Generated:</b> $(Get-Date)<br><b>Administrator:</b> $(Test-IsAdministrator)</p>
<style>body{font-family:Segoe UI,Arial;margin:24px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:8px;vertical-align:top}th{background:#eee}.OK{color:green;font-weight:bold}.Warning{color:#b8860b;font-weight:bold}.Critical{color:red;font-weight:bold}.Info{color:#555;font-weight:bold}</style>
"@
    $table = $Checks | ConvertTo-Html -Fragment -Property Category,Name,Status,Value,Recommendation
    $table = $table -replace '<td>OK</td>', '<td class="OK">OK</td>'
    $table = $table -replace '<td>Warning</td>', '<td class="Warning">Warning</td>'
    $table = $table -replace '<td>Critical</td>', '<td class="Critical">Critical</td>'
    $table = $table -replace '<td>Info</td>', '<td class="Info">Info</td>'
    ConvertTo-Html -Title $ReportName -Body ($htmlHeader + $table) | Set-Content -Path $htmlPath -Encoding UTF8
    Write-Log "Created HTML report: $htmlPath" 'SUCCESS'
    Write-Log "Created CSV report: $csvPath" 'SUCCESS'
    Write-Log "Created JSON report: $jsonPath" 'SUCCESS'
    if ($OpenReport) { try { Start-Process $htmlPath } catch { Write-Log "Could not open report automatically: $($_.Exception.Message)" 'WARN' } }
}

function Show-ChecksAndExport {
    param([object[]]$Checks, [string]$ReportName, [switch]$OpenReport)
    $Checks | Sort-Object Category, Status, Name | Format-Table Category, Name, Status, Value, Recommendation -AutoSize -Wrap
    Export-ToolkitReport -Checks $Checks -ReportName $ReportName -OpenReport:$OpenReport
}

function Get-SystemChecks {
    $checks = @()
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $uptime = (Get-Date) - $os.LastBootUpTime
        $checks += New-Check 'System' 'Operating system' 'Info' "$($os.Caption) $($os.Version) Build $($os.BuildNumber)" 'Record OS version and build in ticket notes.'
        $checks += New-Check 'System' 'Computer model' 'Info' "$($cs.Manufacturer) $($cs.Model)" 'Useful context for device-specific issues.'
        $checks += New-Check 'System' 'Uptime' ($(if ($uptime.TotalDays -gt 14) { 'Warning' } else { 'OK' })) ("{0:N1} days" -f $uptime.TotalDays) 'A restart may be useful if uptime is high.'
        $checks += New-Check 'System' 'Administrator session' ($(if (Test-IsAdministrator) { 'OK' } else { 'Warning' })) "$(Test-IsAdministrator)" 'Administrator rights provide more complete results.'
    }
    catch { $checks += New-Check 'System' 'System query' 'Critical' $_.Exception.Message 'Run PowerShell as Administrator and retry.' }
    return $checks
}

function Get-DiskSpaceChecks {
    $checks = @()
    try {
        $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
        $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        $sizeGB = [math]::Round($drive.Size / 1GB, 2)
        $freePercent = [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 1)
        if ($freeGB -lt 5 -or $freePercent -lt 10) { $status = 'Critical'; $rec = 'Free space is very low.' }
        elseif ($freeGB -lt 15 -or $freePercent -lt 20) { $status = 'Warning'; $rec = 'Low disk space can affect update activity.' }
        else { $status = 'OK'; $rec = 'Disk space looks acceptable.' }
        $checks += New-Check 'Disk Space' "System drive $($env:SystemDrive)" $status "$freeGB GB free of $sizeGB GB ($freePercent%)" $rec
    }
    catch { $checks += New-Check 'Disk Space' 'System drive query' 'Warning' $_.Exception.Message 'Could not query system drive space.' }
    return $checks
}

function Get-ServiceChecks {
    $checks = @()
    foreach ($name in @('wuauserv','BITS','CryptSvc','msiserver','UsoSvc','DoSvc')) {
        try {
            $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
            if (-not $svc) { $checks += New-Check 'Services' $name 'Info' 'Not found' 'Service may not exist on this Windows version.'; continue }
            $status = if ($svc.Status -eq 'Running') { 'OK' } elseif ($svc.StartType -eq 'Disabled') { 'Warning' } else { 'Info' }
            $checks += New-Check 'Services' $svc.DisplayName $status "Name: $($svc.Name); Status: $($svc.Status); StartType: $($svc.StartType)" 'Confirm service state matches support expectations.'
        }
        catch { $checks += New-Check 'Services' $name 'Warning' $_.Exception.Message 'Could not query service.' }
    }
    return $checks
}

function Get-PendingRebootChecks {
    $checks = @(); $reasons = @()
    $paths = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'; Reason = 'Component Based Servicing reboot pending' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'; Reason = 'Windows Update reboot required' }
    )
    foreach ($item in $paths) { try { if (Test-Path $item.Path) { $reasons += $item.Reason } } catch { } }
    try {
        $pendingRename = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
        if ($pendingRename) { $reasons += 'Pending file rename operations' }
    } catch { }
    if ($reasons.Count -gt 0) { $checks += New-Check 'Reboot' 'Pending reboot' 'Warning' ($reasons -join '; ') 'Restart before continuing with update installs.' }
    else { $checks += New-Check 'Reboot' 'Pending reboot' 'OK' 'No common pending reboot indicators found' 'No reboot required based on common checks.' }
    return $checks
}

function Get-HotfixChecks {
    $checks = @()
    try {
        $hotfixes = Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending
        $latest = $hotfixes | Select-Object -First 1
        if ($latest) { $checks += New-Check 'Update History' 'Latest installed hotfix' 'Info' "$($latest.HotFixID); InstalledOn: $($latest.InstalledOn); Description: $($latest.Description)" 'Review update recency against patch policy.' }
        else { $checks += New-Check 'Update History' 'Installed hotfixes' 'Warning' 'No hotfixes returned' 'History may be unavailable or restricted.' }
        $path = Join-Path $ReportRoot "installed_hotfixes_$RunStamp.csv"
        $hotfixes | Select-Object HotFixID,Description,InstalledBy,InstalledOn | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        $checks += New-Check 'Update History' 'Installed hotfix export' 'OK' $path 'Attach this CSV to tickets when patch history is relevant.'
    }
    catch { $checks += New-Check 'Update History' 'Hotfix query' 'Warning' $_.Exception.Message 'Could not query installed hotfixes.' }
    return $checks
}

function Get-WindowsUpdateHistoryChecks {
    $checks = @()
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $count = $searcher.GetTotalHistoryCount()
        $max = [Math]::Min($count, 100)
        $history = $searcher.QueryHistory(0, $max)
        $rows = foreach ($entry in $history) {
            [PSCustomObject]@{ Date=$entry.Date; Title=$entry.Title; ResultCode=$entry.ResultCode; HResult=('0x{0:X8}' -f ($entry.HResult -band 0xffffffff)); Operation=$entry.Operation; Description=$entry.Description }
        }
        $path = Join-Path $ReportRoot "windows_update_history_$RunStamp.csv"
        $rows | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        $attention = @($rows | Where-Object { $_.ResultCode -notin @(2,3) })
        $checks += New-Check 'Update History' 'Windows Update history export' ($(if ($attention.Count -gt 0) { 'Warning' } else { 'OK' })) "$max record(s); $($attention.Count) non-success result(s)" 'Review CSV for titles and result values.'
        $checks += New-Check 'Update History' 'Windows Update history CSV' 'OK' $path 'Attach this CSV to update tickets.'
    }
    catch { $checks += New-Check 'Update History' 'Windows Update COM history' 'Warning' $_.Exception.Message 'Could not query Windows Update COM history.' }
    return $checks
}

function Get-BitsChecks {
    $checks = @()
    try {
        $jobs = Get-BitsTransfer -AllUsers -ErrorAction Stop
        $count = @($jobs).Count
        $attention = @($jobs | Where-Object { $_.JobState -eq 'Error' -or $_.JobState -eq 'TransientError' })
        $checks += New-Check 'BITS' 'BITS jobs' ($(if ($attention.Count -gt 0) { 'Warning' } else { 'OK' })) "$count job(s); $($attention.Count) attention item(s)" 'BITS state can affect downloads.'
        $path = Join-Path $ReportRoot "bits_jobs_$RunStamp.csv"
        $jobs | Select-Object DisplayName,JobState,OwnerAccount,CreationTime,TransferType,Priority,ErrorDescription | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        $checks += New-Check 'BITS' 'BITS job export' 'OK' $path 'Attach this CSV when download problems are suspected.'
    }
    catch { $checks += New-Check 'BITS' 'BITS job query' 'Info' $_.Exception.Message 'Run as Administrator for all-user BITS job visibility.' }
    return $checks
}

function Get-EventChecks {
    param([int]$Hours = 72)
    $checks = @(); $start = (Get-Date).AddHours(-1 * $Hours)
    foreach ($logName in @('System','Microsoft-Windows-WindowsUpdateClient/Operational','Microsoft-Windows-Bits-Client/Operational')) {
        try {
            $events = Get-WinEvent -FilterHashtable @{ LogName=$logName; Level=1,2,3; StartTime=$start } -ErrorAction Stop
            if ($logName -eq 'System') { $events = $events | Where-Object { $_.ProviderName -match 'WindowsUpdateClient|BITS|Service Control Manager' } }
            $eventCount = @($events).Count
            $status = if ($eventCount -gt 25) { 'Warning' } elseif ($eventCount -gt 0) { 'Info' } else { 'OK' }
            $checks += New-Check 'Events' "$logName warning/error events last $Hours hours" $status "$eventCount event(s)" 'Review event IDs and messages when update issues occur.'
            $path = Join-Path $ReportRoot "$($logName -replace '[\\/]', '_')_events_$RunStamp.csv"
            $events | Select-Object TimeCreated,Id,ProviderName,LevelDisplayName,Message | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
            $checks += New-Check 'Events' "Exported events for $logName" 'OK' $path 'Attach this CSV to tickets if relevant.'
        }
        catch { $checks += New-Check 'Events' $logName 'Info' $_.Exception.Message 'Log may be unavailable or disabled.' }
    }
    return $checks
}

function Get-ComponentStoreCheck {
    $checks = @()
    try {
        $output = (& dism.exe /Online /Cleanup-Image /CheckHealth 2>&1) -join ' | '
        if ($output.Length -gt 900) { $output = $output.Substring(0,900) + '...' }
        $checks += New-Check 'Component Store' 'DISM CheckHealth' 'Info' $output 'Use this as context for support escalation.'
    }
    catch { $checks += New-Check 'Component Store' 'DISM CheckHealth' 'Warning' $_.Exception.Message 'Could not run DISM CheckHealth.' }
    return $checks
}

function Get-FullChecks {
    $checks = @()
    $checks += Get-SystemChecks
    $checks += Get-DiskSpaceChecks
    $checks += Get-ServiceChecks
    $checks += Get-PendingRebootChecks
    $checks += Get-HotfixChecks
    $checks += Get-WindowsUpdateHistoryChecks
    $checks += Get-BitsChecks
    $checks += Get-EventChecks -Hours 72
    $checks += Get-ComponentStoreCheck
    return $checks
}

function Invoke-QuickSummary {
    Show-Header
    Write-Host '[1] Quick Windows Update summary' -ForegroundColor Cyan
    $checks = @()
    $checks += Get-SystemChecks
    $checks += Get-DiskSpaceChecks
    $checks += Get-ServiceChecks
    $checks += Get-PendingRebootChecks
    Show-ChecksAndExport -Checks $checks -ReportName 'Quick_Windows_Update_Summary'
    Pause-Menu
}

function Invoke-FullReport {
    Show-Header
    Write-Host '[2] Full Windows Update diagnostic report' -ForegroundColor Cyan
    $checks = Get-FullChecks
    Show-ChecksAndExport -Checks $checks -ReportName 'Full_Windows_Update_Diagnostic_Report' -OpenReport
    Pause-Menu
}

function Invoke-SingleCheck {
    param([Parameter(Mandatory)] [string]$Name)
    Show-Header
    $checks = switch ($Name) {
        'Services' { Get-ServiceChecks }
        'Reboot' { Get-PendingRebootChecks }
        'Hotfixes' { Get-HotfixChecks }
        'History' { Get-WindowsUpdateHistoryChecks }
        'BITS' { Get-BitsChecks }
        'Events' { Get-EventChecks -Hours 72 }
        'Component' { Get-ComponentStoreCheck }
    }
    Show-ChecksAndExport -Checks $checks -ReportName "$Name`_Check"
    Pause-Menu
}

function Invoke-OpenWindowsUpdateSettings {
    Show-Header
    Write-Host '[10] Open Windows Update settings' -ForegroundColor Cyan
    try { Start-Process 'ms-settings:windowsupdate'; Write-Log 'Opened Windows Update settings.' 'SUCCESS' } catch { Write-Log "Could not open Windows Update settings: $($_.Exception.Message)" 'ERROR' }
    Pause-Menu
}

function Open-ReportFolder {
    Show-Header
    Write-Host '[11] Open report folder' -ForegroundColor Cyan
    try { Start-Process explorer.exe -ArgumentList "`"$ReportRoot`""; Write-Log "Opened report folder: $ReportRoot" 'SUCCESS' } catch { Write-Log "Could not open report folder: $($_.Exception.Message)" 'ERROR' }
    Pause-Menu
}

Write-Log "Windows Update Diagnostic Toolkit v$ScriptVersion started."
Write-Log "Administrator: $(Test-IsAdministrator)"
Write-Log "Report folder: $ReportRoot"

if ($RunAll) {
    Invoke-FullReport
    return
}

do {
    Show-Header
    Write-Host '  1. Quick Windows Update summary'
    Write-Host '  2. Full Windows Update diagnostic report'
    Write-Host '  3. Update services check'
    Write-Host '  4. Pending reboot check'
    Write-Host '  5. Installed hotfix export'
    Write-Host '  6. Windows Update history export'
    Write-Host '  7. BITS job check'
    Write-Host '  8. Windows Update event log analyzer'
    Write-Host '  9. Component store health check'
    Write-Host ' 10. Open Windows Update settings'
    Write-Host ' 11. Open report folder'
    Write-Host
    Write-Host '  0. Exit'
    Write-Host
    $choice = Read-Host 'Select an option'
    switch ($choice) {
        '1'  { Invoke-QuickSummary }
        '2'  { Invoke-FullReport }
        '3'  { Invoke-SingleCheck -Name 'Services' }
        '4'  { Invoke-SingleCheck -Name 'Reboot' }
        '5'  { Invoke-SingleCheck -Name 'Hotfixes' }
        '6'  { Invoke-SingleCheck -Name 'History' }
        '7'  { Invoke-SingleCheck -Name 'BITS' }
        '8'  { Invoke-SingleCheck -Name 'Events' }
        '9'  { Invoke-SingleCheck -Name 'Component' }
        '10' { Invoke-OpenWindowsUpdateSettings }
        '11' { Open-ReportFolder }
        '0'  { Write-Log 'Toolkit closed by the user.'; Write-Host 'Goodbye.' -ForegroundColor Green }
        default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
    }
}
while ($choice -ne '0')
