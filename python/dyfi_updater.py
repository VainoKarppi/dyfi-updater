#!/usr/bin/env python3
import json, os, time, base64, requests
from datetime import datetime, timedelta

# Paths
start_dir = os.path.dirname(os.path.abspath(__file__))
settings_path = os.path.join(start_dir, "settings.json")
last_update_file = os.path.join(start_dir, "lastupdate.txt")
log_file = os.path.join(start_dir, "log.log")

# Default settings
default_settings = {
    "Username": "my.email@email.com",
    "Password": "passw0rd",
    "DomainNames": ["address.dy.fi"],
    "ForceUpdateIntervalDays": 6,
    "IpCheckIntervalMinutes": 2,
    "UpdateNow": True,
    "UseLogFile": True
}

# Ensure settings.json exists
if not os.path.exists(settings_path):
    with open(settings_path, "w", encoding="utf-8") as f:
        json.dump(default_settings, f, indent=4)
settings = default_settings.copy()

def log(msg):
    timestamp = datetime.now().strftime("[%Y-%m-%d %H:%M:%S]")
    text = f"{timestamp} {msg}"
    print(text)
    if settings.get("UseLogFile"):
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(text + "\n")

def load_settings():
    global settings
    try:
        with open(settings_path, "r", encoding="utf-8") as f:
            s = json.load(f)
            s["IpCheckIntervalMinutes"] = max(1, s.get("IpCheckIntervalMinutes", 2))
            settings.update(s)
    except Exception as e:
        log(f"Failed to load settings: {e}")

def get_external_ip():
    services = [
        "https://icanhazip.com",
        "https://checkip.amazonaws.com",
        "https://api.ipify.org",
        "https://ifconfig.me"
    ]
    for url in services:
        try:
            r = requests.get(url, timeout=5)
            ip = r.text.strip()
            if ip:
                return ip
        except:
            continue
    raise Exception("Could not retrieve external IP")

def update_domain(domain, ip):
    if not domain.lower().endswith(".dy.fi"):
        domain += ".dy.fi"
    url = f"https://www.dy.fi/nic/update?hostname={domain}"
    auth = (settings["Username"], settings["Password"])
    try:
        r = requests.post(url, auth=auth, data=url, timeout=10)
        resp = r.text.strip().lower()
        if resp == "nochg" or resp.startswith("good"):
            log(f"UPDATED: Domain '{domain}' updated to IP {ip}.")
            return True
        else:
            log(f"Failed to update domain '{domain}': {resp}")
    except Exception as e:
        log(f"ERROR updating {domain}: {e}")
    return False

# Load last update
next_update = datetime.now() + timedelta(days=settings["ForceUpdateIntervalDays"])
last_ip = None
if os.path.exists(last_update_file):
    with open(last_update_file, "r", encoding="utf-8") as f:
        dt = f.read().strip()
        try:
            last_update = datetime.fromisoformat(dt)
            next_update = last_update + timedelta(days=settings["ForceUpdateIntervalDays"])
        except: pass

log("========== DYFI-UPDATER START ==========")
log(f"Root directory: {start_dir}")
log(f"Domains: {settings['DomainNames']}")
log(f"Force update interval: {settings['ForceUpdateIntervalDays']} days")
log(f"IP check interval: {settings['IpCheckIntervalMinutes']} minutes")
log(f"Update immediately on start: {settings['UpdateNow']}")
log(f"Logging to file: {settings['UseLogFile']}")
log("========================================")

# Main loop
while True:
    try:
        load_settings()
        delay = max(1, settings["IpCheckIntervalMinutes"]) * 60
        current_ip = get_external_ip()
        now = datetime.now()

        if current_ip != last_ip or settings["UpdateNow"] or now > next_update:
            for domain in settings["DomainNames"]:
                update_domain(domain, current_ip)
            last_ip = current_ip
            settings["UpdateNow"] = False
            next_update = now + timedelta(days=settings["ForceUpdateIntervalDays"])
            with open(last_update_file, "w", encoding="utf-8") as f:
                f.write(datetime.now().isoformat())
        time.sleep(delay)
    except Exception as e:
        log(f"ERROR: {e} - retrying in {settings.get('IpCheckIntervalMinutes',2)} minutes")
        time.sleep(max(1, settings.get("IpCheckIntervalMinutes",2))*60)