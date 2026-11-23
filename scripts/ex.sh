#!/bin/sh

SESSION_FILE=".session"

# Ensure an active session exists
if [ ! -f "$SESSION_FILE" ]; then
    echo "No active session."
    exit 1
fi

SESSION_DIR=$(cat "$SESSION_FILE")
CSV_FILE="$SESSION_DIR/exercises.csv"

# Get session code from session.yml
SESSION_YML="$SESSION_DIR/session.yml"
SESSION_CODE=$(awk -F': ' '/^code:/ {print $2}' "$SESSION_YML")

# Create CSV if needed
[ -f "$CSV_FILE" ] || \
    echo "exercise_id,exercise_uuid,turn_id,user_uuid,start_time,stop_time,duration_seconds" > "$CSV_FILE"

# Determine next exercise ID
LAST_EX_ID=$(tail -n 1 "$CSV_FILE" | cut -d, -f1)

if [ "$LAST_EX_ID" = "exercise_id" ] || [ -z "$LAST_EX_ID" ]; then
    EX_NUM=1
else
    EX_NUM=$(expr "$LAST_EX_ID" + 1)
fi

EXERCISE_ID=$(printf "%02d" "$EX_NUM")

SUBJECTS_CSV="$SESSION_DIR/subjects.csv"

# Ask for TURN_ID with numeric validation and existence check
clear
while true; do
    TURN_INPUT=$(gum input --prompt "Turn ID (numbers only, e.g., 1): " --placeholder "1")

    # Check if input consists solely of digits
    if ! printf '%s\n' "$TURN_INPUT" | grep -Eq '^[0-9]+$'; then
        gum style --foreground 196 "Invalid input. Turn ID must be a number." >&2
        gum confirm "Retry?" || exit 1
        clear
        continue
    fi

    # Format as a two-digit number (e.g., 1 -> 01)
    TURN_ID=$(printf "%02d" "$TURN_INPUT")

    # Check if the TURN_ID exists in subjects.csv
    if [ ! -f "$SUBJECTS_CSV" ]; then
        gum style --foreground 196 "No participants registered. Please register participants first." >&2
        exit 1
    fi

    if grep -q "^$TURN_ID," "$SUBJECTS_CSV"; then
        # Turn ID found, get user_uuid from subjects.csv
        USER_UUID=$(grep "^$TURN_ID," "$SUBJECTS_CSV" | cut -d, -f3)
        if [ -z "$USER_UUID" ]; then
            gum style --foreground 196 "Error: Could not find user_uuid for Turn ID $TURN_ID" >&2
            exit 1
        fi
        break
    fi

    gum style --foreground 196 "Turn ID $TURN_ID not found. Please register this participant first or try another ID." >&2
    gum confirm "Retry?" || exit 1
    clear
done

clear
gum style --bold "Exercise $EXERCISE_ID Started for Turn ID: $TURN_ID"
echo "Press 'q' to stop the timer."
echo

# Record start time (ISO 8601 format)
START_EPOCH=$(date +%s)
START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

stty -echo
# Stopwatch loop running until 'q' is pressed
while true; do
    CURRENT_EPOCH=$(date +%s)
    ELAPSED=$((CURRENT_EPOCH - START_EPOCH))
    
    HOURS=$((ELAPSED / 3600))
    MINUTES=$(( (ELAPSED % 3600) / 60 ))
    SECONDS=$((ELAPSED % 60))

    # Print live timer overwriting the same line
    printf "\r⏱️  Elapsed Time: %02d:%02d:%02d" "$HOURS" "$MINUTES" "$SECONDS"

    # Non-blocking check for 'q' key press
    read -t 1 -n 1 key
    if [ "$key" = "q" ] || [ "$key" = "Q" ]; then
        echo
        break
    fi
done
stty echo

# Record stop time
STOP_EPOCH=$(date +%s)
STOP_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DURATION=$((STOP_EPOCH - START_EPOCH))

# Generate exercise_uuid with session code as prefix
EXERCISE_UUID="${SESSION_CODE}_$(printf '%02d' "$EX_NUM")"

# Append to exercises CSV
printf '%s,%s,%s,%s,%s,%s,%s\n' \
    "$EXERCISE_ID" \
    "$EXERCISE_UUID" \
    "$TURN_ID" \
    "$USER_UUID" \
    "$START_TIME" \
    "$STOP_TIME" \
    "$DURATION" \
    >> "$CSV_FILE"

clear
echo
gum style --foreground 46 --bold "Exercise $EXERCISE_ID saved successfully! Duration: ${DURATION}s"
