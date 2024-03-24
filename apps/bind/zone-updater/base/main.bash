#!/bin/bash

#######################################################
#                                                     #
#  Obtains the current external IP, compares it       #
#  against the defined IPs in the bind config         #
#  files and, if they do not match, it modifies them  #
#                                                     #
#######################################################

# Function for logging to stdout
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

#############
# Variables #
#############

# Array of files to be modified
bindconfigs=(
    "/etc/bind/master/nahue.ar.zone"
    "/etc/bind/master/podvader.com.zone"
    "/etc/bind/master/podvader.info.zone"
    "/etc/bind/master/podvader.net.zone"
    "/etc/bind/master/podvader.online.zone"
    "/etc/bind/master/podvader.org.zone"
)

# Current external IP
currextip=$(curl -s --connect-timeout 5 --max-time 10 --retry 5 --retry-delay 0 --retry-max-time 40 'https://ifconfig.me' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')

# Flag to track modifications
modified=false

if ping -c 1 -n -q -s 4 -W 5 8.8.8.8 &>/dev/null; then

    log "Internet is reachable."
    # Iterate over each bindconfig file
    for bindconfig in "${bindconfigs[@]}"; do
        # Current bind config file IP
        currbindip=$(grep -Eo '([0-9]*\.){3}[0-9]*' "$bindconfig")

        # Current serial number
        currbindser=$(grep -i serial "$bindconfig" | grep -Eo '([0-9]*)')

        # Current serial number substring
        currbindsersub=${currbindser:0:8}

        # Same date serial plus one
        newserial1=$((currbindser + 1))

        # Current date YYYYMMDD
        currdate=$(date +%Y%m%d)

        # Current date serial format YYYYMMDDXX
        newserial=$(date +%Y%m%d)01

        log "Starting dynbind process for $bindconfig"

        if [ -z "$currextip" ]; then # Checks if currextip has zero length
            log "Zero length IP for $bindconfig"
            continue
        fi

        if [ "$currextip" != "$currbindip" ]; then # Compares the current external IP against the one in the zone file
            log "External IP and Bind IP are different for $bindconfig. Updating"
            sed -i -e "s/$currbindip/$currextip/g" "$bindconfig"       # Replaces all the occurrences of current file IP found with the new IP on bindconfig
            if [ "$currbindsersub" = "$currdate" ]; then               # Compares the date within the current serial number against the current date
                sed -i -e "s/$currbindser/$newserial1/g" "$bindconfig" # Adds one to the current serial on bindconfig
                log "Serial is from the same date. New serial for $bindconfig is $newserial1"
            else
                sed -i -e "s/$currbindser/$newserial/g" "$bindconfig" # Replaces the old serial with the new one on bindconfig
                log "Serial is from different date. New serial for $bindconfig is $newserial"
            fi
            modified=true # Set the flag to indicate modifications
        else
            log "External IP and Bind IP match for $bindconfig"
        fi

    done

    if [ "$modified" = true ]; then
        log "Modifications detected. Restarting bind-external deployment."
        kubectl rollout restart -n bind9 deployment bind-external
    else
        log "No modifications detected. Skipping deployment restart."
    fi

else
    log "Internet is unreachable for $bindconfig"
fi

log "Dynbind process completed"
