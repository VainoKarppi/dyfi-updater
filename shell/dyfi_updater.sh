#!/bin/bash

SETTINGS="settings.json"
LASTUPDATE="lastupdate.txt"
LOG="log.log"

# Default settings
if [ ! -f "$SETTINGS" ]; then
  cat >"$SETTINGS" <<EOF
{
  "Username": "my.email@email.com",
  "Password": "passw0rd",
  "DomainNames": ["address.dy.fi"],
  "ForceUpdateIntervalDays": 6,
  "IpCheckIntervalMinutes": 2,
  "UpdateNow": true,
  "UseLogFile": true
}
EOF
fi

function log_msg {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

function get_ip {
    for svc in "https://icanhazip.com" "https://checkip.amazonaws.com" "https://api.ipify.org" "https://ifconfig.me"; do
        ip=$(curl -s --max-time 5 $svc)
        if [[ -n "$ip" ]]; then echo "$ip"; return; fi
    done
    echo "ERROR"
}

# Main loop
last_ip=""
while true; do
    IP_CHECK_INTERVAL=$(jq -r '.IpCheckIntervalMinutes' "$SETTINGS")
    [ "$IP_CHECK_INTERVAL" -le 1 ] && IP_CHECK_INTERVAL=2

    current_ip=$(get_ip)
    if [[ "$current_ip" == "ERROR" ]]; then
        log_msg "Failed to fetch external IP, retrying in $IP_CHECK_INTERVAL minutes..."
        sleep $((IP_CHECK_INTERVAL*60))
        continue
    fi

    UPDATE_NOW=$(jq -r '.UpdateNow' "$SETTINGS")
    FORCE_DAYS=$(jq -r '.ForceUpdateIntervalDays' "$SETTINGS")
    DOMAINS=$(jq -r '.DomainNames[]' "$SETTINGS")

    # Only update if IP changed or forced
    if [[ "$current_ip" != "$last_ip" || "$UPDATE_NOW" == "true" ]]; then
        for domain in $DOMAINS; do
            [[ "$domain" != *.dy.fi ]] && domain="$domain.dy.fi"
            curl -su "$(jq -r '.Username' "$SETTINGS"):$(jq -r '.Password' "$SETTINGS")" \
                 -d "hostname=$domain" "https://www.dy.fi/nic/update?hostname=$domain"
            log_msg "UPDATED: $domain to $current_ip"
        done
        last_ip=$current_ip
        sed -i 's/"UpdateNow": true/"UpdateNow": false/' "$SETTINGS"
        date +"%Y-%m-%dT%H:%M:%S" > "$LASTUPDATE"
    fi

    sleep $((IP_CHECK_INTERVAL*60))
done