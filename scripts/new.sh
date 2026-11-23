#!/bin/sh

SESSION_FILE=".session"

# Ensure an active session exists
if [ ! -f "$SESSION_FILE" ]; then
    echo "No active session."
    exit 1
fi

SESSION_DIR=$(cat "$SESSION_FILE")
CSV_FILE="$SESSION_DIR/subjects.csv"

# Get or create persistent user UUID
get_or_create_user_uuid() {
    user_id="$1"
    users_file="data/users.csv"
    
    # Initialize global users file if needed
    if [ ! -f "$users_file" ]; then
        echo "user_id,user_uuid,first_registration,last_registration" > "$users_file"
    fi
    
    # Check if user exists
    existing_uuid=$(grep "^${user_id}," "$users_file" | cut -d, -f2)
    
    if [ -n "$existing_uuid" ]; then
        # User exists - update last_registration
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        # Create temp file and replace original
        grep -v "^${user_id}," "$users_file" > "${users_file}.tmp"
        echo "$user_id,$existing_uuid,$(grep "^${user_id}," "$users_file" | cut -d, -f3),$timestamp" >> "${users_file}.tmp"
        mv "${users_file}.tmp" "$users_file"
        echo "$existing_uuid"
    else
        # New user - create entry
        user_uuid=$(uuidgen --time-v7)
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "$user_id,$user_uuid,$timestamp,$timestamp" >> "$users_file"
        echo "$user_uuid"
    fi
}

# Create CSV if needed
[ -f "$CSV_FILE" ] || \
    echo "turn_id,record_uuid,user_uuid,user_id,age,weight,height,gender,main_hand,share" > "$CSV_FILE"

get_required() {
    prompt="$1"
    placeholder="$2"

    while true; do
        value=$(gum input --prompt "$prompt" --placeholder "$placeholder")
        if [ -n "$value" ]; then
            printf '%s' "$value"
            return
        fi
        gum style --foreground 196 "This field is required." >&2
    done
}

get_number() {
    prompt="$1"
    placeholder="$2"

    while true; do
        value=$(gum input --prompt "$prompt" --placeholder "$placeholder")

        [ -z "$value" ] && {
            printf '%s' ""
            return
        }

        printf '%s\n' "$value" | grep -Eq '^[0-9]+(\.[0-9]+)?$' && {
            printf '%s' "$value"
            return
        }

        gum confirm "Invalid number. Retry?" || exit 1
    done
}

clear

gum style --bold "Register Participant"

USER_ID=$(get_required "DNI: " "12345678Z")
AGE=$(get_number "Age (years): " "27")
HEIGHT=$(get_number "Height (cm): " "175")
WEIGHT=$(get_number "Weight (kg): " "75")

clear
echo "Gender"
GENDER=$(gum choose Male Female Other)

clear
echo "Main hand"
MAIN_HAND=$(gum choose Right Left)

clear
echo "Share anonymous data"
SHARE=$(gum choose Yes No)

RECORD_UUID=$(uuidgen --time-v7)
USER_UUID=$(get_or_create_user_uuid "$USER_ID")

# Determine next turn ID
LAST_TURN=$(tail -n 1 "$CSV_FILE" | cut -d, -f1)

if [ "$LAST_TURN" = "turn_id" ] || [ -z "$LAST_TURN" ]; then
    TURN_NUM=1
else
    TURN_NUM=$(expr "$LAST_TURN" + 1)
fi
clear

TURN_ID=$(printf "%02d" "$TURN_NUM")

# Append participant
printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$TURN_ID" \
    "$RECORD_UUID" \
    "$USER_UUID" \
    "$USER_ID" \
    "$AGE" \
    "$WEIGHT" \
    "$HEIGHT" \
    "$GENDER" \
    "$MAIN_HAND" \
    "$SHARE" \
    >> "$CSV_FILE"

gum style --foreground 46 --bold "Participant registered."

gum style --foreground 214 --bold "Please remember your turn ID: $TURN_ID"
