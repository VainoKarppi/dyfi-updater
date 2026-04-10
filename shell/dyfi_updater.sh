#!/bin/bash

SETTINGS="settings.json"
LASTUPDATE="lastupdate.txt"
LOG="log.log"

# -------------------------
# Default settings
# -------------------------
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

# -------------------------
# JSON helpers
# -------------------------
json_get_string() {
    grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$SETTINGS" \
        | head -n 1 \
        | sed 's/.*:[[:space:]]*"\(.*\)"/\1/' \
        | tr -d '\r'
}

json_get_number() {
    grep -o "\"$1\"[[:space:]]*:[[:space:]]*[0-9]*" "$SETTINGS" \
        | head -n 1 \
        | grep -o '[0-9]*$' \
        | tr -d '\r'
}

json_get_bool() {
    val=$(grep -o "\"$1\"[[:space:]]*:[[:space:]]*\(true\|false\)" "$SETTINGS" \
        | head -n 1 \
        | grep -o 'true\|false' \
        | tr -d '\r')
    [[ "$val" == "true" ]] && echo "true" || echo "false"
}

json_get_array() {
    tr -d '\r\n' < "$SETTINGS" \
        | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\[[^]]*\]" \
        | grep -o '\[.*\]' \
        | tr -d '[]' \
        | tr ',' '\n' \
        | tr -d '"' \
        | tr -d ' ' \
        | sed '/^$/d'
}

# -------------------------
# Logging
# -------------------------
log() {
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    if [[ "$(json_get_bool "UseLogFile")" == "true" ]]; then
        echo "$msg" >> "$LOG"
    fi
}

# -------------------------
# Load settings
# -------------------------
load_settings() {
    USERNAME=$(json_get_string "Username")
    PASSWORD=$(json_get_string "Password")
    FORCE_DAYS=$(json_get_number "ForceUpdateIntervalDays")
    IP_INTERVAL=$(json_get_number "IpCheckIntervalMinutes")
    USE_LOG=$(json_get_bool "UseLogFile")
    DOMAINS=$(json_get_array "DomainNames")

    [[ -z "$FORCE_DAYS" ]]     && FORCE_DAYS=6
    [[ -z "$IP_INTERVAL" ]]    && IP_INTERVAL=2
    [[ "$IP_INTERVAL" -lt 1 ]] && IP_INTERVAL=1
}

# -------------------------
# External IP
# -------------------------
get_external_ip() {
    for url in \
        "https://icanhazip.com" \
        "https://checkip.amazonaws.com" \
        "https://api.ipify.org" \
        "https://ifconfig.me"
    do
        ip=$(curl -s --max-time 5 "$url" | tr -d '[:space:]')
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    done
    return 1
}

# -------------------------
# Update domain
# -------------------------
update_domain() {
    domain="$1"
    ip="$2"

    [[ "$domain" != *.dy.fi ]] && domain="${domain}.dy.fi"

    url="https://www.dy.fi/nic/update?hostname=${domain}&myip=${ip}"
    response=$(curl -s --max-time 10 -u "${USERNAME}:${PASSWORD}" "$url")
    response_lower=$(echo "$response" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

    if [[ "$response_lower" == "nochg" || "$response_lower" == good* ]]; then
        log "UPDATED: Domain '$domain' updated to IP $ip."
        return 0
    else
        log "ERROR: Failed to update domain '$domain': '$response'"
        return 1
    fi
}

# -------------------------
# Timestamp helpers
# -------------------------
now_ts() {
    date +%s
}

iso_to_ts() {
    date -d "$1" +%s 2>/dev/null
}

# -------------------------
# Init
# -------------------------
load_settings

# Read UpdateNow once at startup — never written back to file
UPDATE_NOW_ONCE=$(json_get_bool "UpdateNow")

last_ip=""
current_ts=$(now_ts)
next_update_ts=$((current_ts + FORCE_DAYS * 86400))

if [ -f "$LASTUPDATE" ]; then
    last_time=$(cat "$LASTUPDATE")
    parsed_ts=$(iso_to_ts "$last_time")
    if [[ -n "$parsed_ts" ]]; then
        next_update_ts=$((parsed_ts + FORCE_DAYS * 86400))
    fi
fi

# -------------------------
# Startup log
# -------------------------
log "========== DYFI-UPDATER START =========="
log "Root directory: $(pwd)"
log "Domains: $(json_get_array "DomainNames" | tr '\n' ' ')"
log "Force update interval: ${FORCE_DAYS} days"
log "IP check interval: ${IP_INTERVAL} minutes"
log "Update immediately on start: ${UPDATE_NOW_ONCE}"
log "Logging to file: ${USE_LOG}"
log "========================================"

# -------------------------
# Main loop
# -------------------------
while true; do
    load_settings

    current_ip=$(get_external_ip)

    if [[ -z "$current_ip" ]]; then
        log "ERROR: Could not retrieve external IP - retrying in ${IP_INTERVAL} minutes"
        sleep $((IP_INTERVAL * 60))
        continue
    fi

    current_ts=$(now_ts)

    ip_changed=false
    force_due=false
    [[ "$current_ip" != "$last_ip" ]]         && ip_changed=true
    [[ "$current_ts" -gt "$next_update_ts" ]] && force_due=true

    if [[ "$ip_changed" == "true" || "$UPDATE_NOW_ONCE" == "true" || "$force_due" == "true" ]]; then

        while IFS= read -r domain; do
            [[ -z "$domain" ]] && continue
            update_domain "$domain" "$current_ip"
        done <<< "$DOMAINS"

        last_ip="$current_ip"
        UPDATE_NOW_ONCE="false"
        next_update_ts=$((current_ts + FORCE_DAYS * 86400))
        date -Iseconds > "$LASTUPDATE"
    fi

    sleep $((IP_INTERVAL * 60))
done