$SettingsPath = ".\settings.json"
$LastUpdateFile = ".\lastupdate.txt"
$LogFile = ".\log.log"

# Default settings
if (-not (Test-Path $SettingsPath)) {
    $DefaultSettings = @{
        Username = "my.email@email.com"
        Password = "passw0rd"
        DomainNames = @("address.dy.fi")
        ForceUpdateIntervalDays = 6
        IpCheckIntervalMinutes = 2
        UpdateNow = $true
        UseLogFile = $true
    }
    $DefaultSettings | ConvertTo-Json -Depth 3 | Set-Content $SettingsPath
}

function Log($msg){
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
    Write-Host $line
    if ($Settings.UseLogFile) { Add-Content $LogFile $line }
}

function Load-Settings{
    $s = Get-Content $SettingsPath | ConvertFrom-Json
    $s.IpCheckIntervalMinutes = [Math]::Max(1, $s.IpCheckIntervalMinutes)
    return $s
}

function Get-ExternalIP{
    $services = @("https://icanhazip.com","https://checkip.amazonaws.com","https://api.ipify.org","https://ifconfig.me")
    foreach ($svc in $services){
        try{
            $ip = Invoke-RestMethod -Uri $svc -UseBasicParsing -TimeoutSec 5
            if ($ip){ return $ip.Trim() }
        } catch {}
    }
    throw "Failed to get external IP"
}

$Settings = Load-Settings
$NextUpdate = (Get-Date).AddDays($Settings.ForceUpdateIntervalDays)
$LastIp = $null

if (Test-Path $LastUpdateFile){
    try { $dt = Get-Content $LastUpdateFile | Get-Date; $NextUpdate = $dt.AddDays($Settings.ForceUpdateIntervalDays) } catch {}
}

Log "========== DYFI-UPDATER START =========="
Log "Domains: $($Settings.DomainNames -join ', ')"
Log "IP check interval: $($Settings.IpCheckIntervalMinutes) minutes"
Log "Force update interval: $($Settings.ForceUpdateIntervalDays) days"
Log "Logging to file: $($Settings.UseLogFile)"
Log "========================================"

while ($true){
    try{
        $Settings = Load-Settings
        $Delay = [TimeSpan]::FromMinutes($Settings.IpCheckIntervalMinutes)
        $CurrentIp = Get-ExternalIP
        $Now = Get-Date

        if ($CurrentIp -ne $LastIp -or $Settings.UpdateNow -or $Now -gt $NextUpdate){
            foreach ($domain in $Settings.DomainNames){
                if (-not $domain.ToLower().EndsWith(".dy.fi")){ $domain += ".dy.fi" }
                $url = "https://www.dy.fi/nic/update?hostname=$domain"
                $pair = "$($Settings.Username):$($Settings.Password)"
                try{
                    $resp = Invoke-RestMethod -Uri $url -Method Post -Credential (New-Object System.Management.Automation.PSCredential($Settings.Username,(ConvertTo-SecureString $Settings.Password -AsPlainText -Force))) -Body $url
                    Log "UPDATED: $domain to $CurrentIp"
                } catch { Log "Failed updating $domain: $_" }
            }
            $LastIp = $CurrentIp
            $Settings.UpdateNow = $false
            Set-Content $LastUpdateFile (Get-Date).ToString("o")
            $NextUpdate = $Now.AddDays($Settings.ForceUpdateIntervalDays)
        }
        Start-Sleep -Seconds ($Delay.TotalSeconds)
    } catch {
        Log "ERROR: $_ - retrying in $($Settings.IpCheckIntervalMinutes) minutes"
        Start-Sleep -Seconds ($Settings.IpCheckIntervalMinutes*60)
    }
}