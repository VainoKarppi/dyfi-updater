# DYFI Updater

## Overview
This is a simple updater script to automatically update DNS for the **dy.fi** free domain system.  
It supports multiple implementations: **C#**, **Python**, **PowerShell**, **Bash**, and **Docker**.

The script monitors your external IP and updates the domains automatically.  
The DNS entries are released by the host after 7 days, so do not set the update interval lower than 3 days.

---

## Supported Implementations

- **C#** (`csharp/`)
- **Python** (`python/`)
- **PowerShell** (`powershell/`)
- **Bash / Shell** (`shell/`)
- **Docker** (`docker/`) — runs Python version inside a container.

---

## Getting Started

### 1. Configure `settings.json`

Each implementation has its own `settings.json` (or use the example provided).  
Set:

- `Username` – your dy.fi account email  
- `Password` – your dy.fi password  
- `DomainNames` – array of domains to update  
- `ForceUpdateIntervalDays` – how often to force an update (minimum 3)  
- `IpCheckIntervalMinutes` – how often to check your external IP  
- `UpdateNow` – set `true` to force immediate update on start  
- `UseLogFile` – set `true` to write logs to `log.log`

Example:

```json
{
  "Username": "my.email@email.com",
  "Password": "passw0rd",
  "DomainNames": ["address.dy.fi"],
  "ForceUpdateIntervalDays": 6,
  "IpCheckIntervalMinutes": 2,
  "UpdateNow": true,
  "UseLogFile": true
}