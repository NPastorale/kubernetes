#!/bin/bash

#######################################################
#                                                     #
#  Obtains the current external IP, compares it       #
#  against the defined IPs in the bind config         #
#  file and, if they do not match, it modifies them   #
#                                                     #
#######################################################

# Function for logging to stdout
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

#############
# Variables #
#############

# Files to be modified
bindconfig=/etc/bind/master/nahue.ar.zone

# Current external IP
currextip=$(curl -s --connect-timeout 5 --max-time 10 --retry 5 --retry-delay 0 --retry-max-time 40 'https://ifconfig.me' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')

# Current bind config file IP
currbindip=$(grep -Eo '([0-9]*\.){3}[0-9]*' $bindconfig)

# Current serial number
currbindser=$(grep Serial $bindconfig | grep -Eo '([0-9]*)')

# Current serial number substring
currbindsersub=${currbindser:0:8}

# Same date serial plus one
newserial1=$((currbindser + 1))

# Current date YYYYMMDD
currdate=$(date +%Y%m%d)

# Current date serial format YYYYMMDDXX
newserial=$(date +%Y%m%d)01

log "Starting dynbind process"

if [ -z "$currextip" ]; then # Checks if currextip has zero lenght
    log "Zero length IP"
    log "Terminated"
    exit
fi

if ping -c 1 -n -q -s 4 -W 5 8.8.8.8 &>/dev/null; then
    if [ "$currextip" != "$currbindip" ]; then # Compares the current external IP against the one in the zone file
        log "Internet is reachable"
        log "External IP and Bind IP are different"
        sed -i -e "s/$currbindip/$currextip/g" "$bindconfig" # Replaces all the occurrences of current file IP found with the new IP on bindconfig
        log "Updating IPs..."
        if [ "$currbindsersub" = "$currdate" ]; then               # Compares the date within the current serial number against the current date
            sed -i -e "s/$currbindser/$newserial1/g" "$bindconfig" # Adds one to the current serial on bindconfig
            log "Serial is from the same date. Adding one..."
        else
            sed -i -e "s/$currbindser/$newserial/g" "$bindconfig" # Replaces the old serial with the new one on bindconfig
            log "Serial is from different date. Changing serial..."
        fi
        kubectl rollout restart -n bind9 deployment bind-external

    else
        log "External IP and Bind IP match"
        log "Terminated"
        exit
    fi
else
    log "Internet is unreachable"
    log "Terminated"
    exit
fi
