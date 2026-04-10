# DYFI Updater

## 📖 Overview

This is a simple updater script to automatically update DNS for the **dy.fi** free domain system.  
It is built specifically for the dy.fi service at https://www.dy.fi/, which provides free dynamic DNS hostnames under the `.dy.fi` domain.

The dy.fi service lets Finnish users reserve up to five `.dy.fi` hostnames and point them to a home computer, website, or other IP address.  
This is useful when your ISP assigns a dynamic IP address and you want a stable, easy-to-remember hostname that follows your current address.

If your dy.fi name is not pointed at an IP address, dy.fi can also forward visitors to a configured home page URL.

The service is offered for free as a hobby project, with minimal guarantees, and is targeted at Finnish users.  
It can also be used as a short alias for a longer web address or as a CNAME target for your own domain.

---

## ✨ Features

- Supports multiple implementations:
  - **C#**
  - **Python**
  - **PowerShell**
  - **Bash**
  - **Docker**
- Automatically monitors your external IP
- Updates DNS records when changes are detected

> ⚠️ The DNS entries are released by the host after 7 days, so do not set the update interval lower than 3 days.

---

## 📦 Release

A release package is available at:  
https://github.com/VainoKarppi/dyfi-updater/releases/latest

This repository now includes Python, PowerShell, Shell, and Docker versions in addition to the original C# implementation.

---

## 🧩 Supported Implementations

- **C#** (`csharp/`)
- **Python** (`python/`)
- **PowerShell** (`powershell/`)
- **Bash / Shell** (`shell/`)
- **Docker** (`docker/`) — runs Python version inside a container

---

## 🛠️ Getting Started

### ⚙️ 1. Configure `settings.json`

Each implementation has its own `settings.json` (or use the example provided).

Set the following values:

- `Username` – your dy.fi account email  
- `Password` – your dy.fi password  
- `DomainNames` – array of domains to update  
  - You do not need to include `.dy.fi`; it is appended automatically if missing  
- `ForceUpdateIntervalDays` – how often to force an update (minimum 3)  
- `IpCheckIntervalMinutes` – how often to check your external IP  
- `UpdateNow` – set `true` to force immediate update on start  
- `UseLogFile` – set `true` to write logs to `log.log`

### 🧪 Example

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