#!/bin/bash

# Define options as an array
OPTIONS=(-rtlhH4 --stats --no-motd --safe-links --delete-after --delay-updates --exclude=lastsync --info=progress2)
DESTINATION="/data/"
MIRRORS="/script/mirrors.txt"
MIRRORS_UPDATED=$(mktemp)
MIRRORS_SHUFFLED=$(mktemp)
MIRROR_SELECTED=$(mktemp)

# Function for logging to stdout
log() {
	echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

if [ ! -f "${DESTINATION}lastupdate" ]; then
	echo "0" >"${DESTINATION}lastupdate"
	log "Initialized lastupdate file"
fi

# Initializing variables for tracking latest update and corresponding mirror
SOURCE=""
START_TIME=$(date +%s)
log "Sync process started"

# Fetch last update timestamps and store in array concurrently
xargs -n 1 -P 20 -I {} sh -c '
	temp_lastupdate=$(curl \
		--connect-timeout 3 \
		--max-time 10 \
		--retry 5 \
		--retry-delay 0 \
		--retry-max-time 10 \
		--silent \
		--ipv4 \
		--fail \
		"https://{}lastupdate" || echo "0")
	echo "$temp_lastupdate {}"' <"$MIRRORS" >"$MIRRORS_UPDATED"

# Find the most up to date copy
MOST_UP_TO_DATE=$(sort -rn $MIRRORS_UPDATED | head -n 1 | awk '{print $1}')

# Filter and shuffle lines that start with the highest number
grep -E "^$MOST_UP_TO_DATE\s" $MIRRORS_UPDATED | shuf - >$MIRRORS_SHUFFLED

head -n 1 $MIRRORS_SHUFFLED >$MIRROR_SELECTED

log "Most up to date mirror:   $(date -d @$MOST_UP_TO_DATE)"

log "Local mirror last update: $(date -d @$(cat ${DESTINATION}lastupdate))"

if [ $(cat ${DESTINATION}lastupdate) -lt $MOST_UP_TO_DATE ]; then
	log "Syncing with $(cat $MIRROR_SELECTED | cut -d ' ' -f 2- | cut -f1 -d"/")"
	rsync $OPTIONS rsync://$(cat $MIRROR_SELECTED | cut -d ' ' -f 2-) $DESTINATION
	log "Sync completed"

else
	log "No sync necessary"
fi

# Update last sync time
date +%s >"${DESTINATION}lastsync"

# Remove temporary file
rm "$MIRRORS_SHUFFLED"

# Calculate total execution time
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
log "Completed in $(date -u -d @"$TOTAL_TIME" +"%T")"
