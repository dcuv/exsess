#!/bin/sh

SESSION_FILE=".session"

# Ensure an active session exists
if [ ! -f "$SESSION_FILE" ]; then
    echo "No active session."
    exit 1
fi

SESSION_DIR=$(cat "$SESSION_FILE")
CSV_FILE="$SESSION_DIR/subjects.csv"

# Create CSV if needed
[ -f "$CSV_FILE" ] || \
    echo "turn_id,record_uuid,user_id,age,weight,height,gender,main_hand,share" > "$CSV_FILE"

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
MAIN_HAND=$(gum choose Rigth Left)

clear
echo "Share anonymous data"
SHARE=$(gum choose Yes No)

RECORD_UUID=$(uuidgen --time-v7)

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
printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$TURN_ID" \
    "$RECORD_UUID" \
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

