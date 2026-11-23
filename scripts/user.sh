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
    echo "turn_id,record_uuid,user_id,age,weight,height,gender,main_hand" > "$CSV_FILE"

# Mandatory field
while true; do
    printf "User ID: "
    read -r USER_ID

    [ -n "$USER_ID" ] && break

    echo "User ID is required."
done

# Optional fields
printf "Age (years): "
read -r AGE

printf "Weight (kg): "
read -r WEIGHT

printf "Height (cm): "
read -r HEIGHT

printf "Gender (M/F/O): "
read -r GENDER

printf "Main hand (L/R): "
read -r MAIN_HAND

RECORD_UUID=$(uuidgen --time-v7)

# Determine next turn ID
LAST_TURN=$(tail -n 1 "$CSV_FILE" | cut -d, -f1)

if [ "$LAST_TURN" = "turn_id" ] || [ -z "$LAST_TURN" ]; then
    TURN_NUM=1
else
    TURN_NUM=$((10#$LAST_TURN + 1))
fi

TURN_ID=$(printf "%02d" "$TURN_NUM")

# Append participant
printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$TURN_ID" \
    "$RECORD_UUID" \
    "$USER_ID" \
    "$AGE" \
    "$WEIGHT" \
    "$HEIGHT" \
    "$GENDER" \
    "$MAIN_HAND" \
    >> "$CSV_FILE"

echo "Participant registered."
printf '%s\n' "$TURN_ID"
