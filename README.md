# Windows Update Repair Toolkit

A menu-driven PowerShell toolkit for L1/L2 IT support Windows Update troubleshooting.

This project helps collect Windows Update support evidence for common helpdesk scenarios, including update service state, pending restart indicators, disk space, update history, hotfix inventory, BITS job state, Windows Update event logs, and component store health.

## Features

- Quick Windows Update summary
- Full Windows Update troubleshooting report
- Update-related service checks
- Pending reboot detection
- Disk space check
- Installed hotfix export
- Windows Update history export
- Windows Update event log analyzer
- BITS job check and export
- Component store health check
- SFC and DISM maintenance options with confirmation
- Windows Update cache maintenance guidance with confirmation
- Open Windows Update settings
- HTML, CSV, JSON, TXT, and log output

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or later
- Administrator rights recommended
- Internet access may be required for some repair operations

## How to run

Open PowerShell as Administrator and run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Update_Repair_Toolkit.ps1
```

Run a full report directly:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Update_Repair_Toolkit.ps1 -RunAll
```

## Menu options

| Option | Description |
|---|---|
| 1 | Quick Windows Update summary |
| 2 | Full Windows Update troubleshooting report |
| 3 | Update services check |
| 4 | Pending reboot check |
| 5 | Update history and hotfix export |
| 6 | Windows Update event log analyzer |
| 7 | BITS job check |
| 8 | Run System File Checker |
| 9 | Run DISM ScanHealth |
| 10 | Run DISM RestoreHealth |
| 11 | Windows Update cache maintenance guidance |
| 12 | Open Windows Update settings |
| 13 | Open report folder |

## Output

Reports are saved on the desktop in `Windows_Update_Repair_Reports` by default.

## Suggested repo topics

```text
powershell
windows-update
windows
it-support
helpdesk
troubleshooting
sysadmin
dism
sfc
patch-management
```
