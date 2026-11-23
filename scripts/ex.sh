#!/bin/sh

SESSION_FILE=".session"

# Ensure an active session exists
if [ ! -f "$SESSION_FILE" ]; then
    echo "No active session."
    exit 1
fi

SESSION_DIR=$(cat "$SESSION_FILE")
CSV_FILE="$SESSION_DIR/exercises.csv"

# Create CSV if needed
[ -f "$CSV_FILE" ] || \
    echo "exercise_id,turn_id,start_time,stop_time,duration_seconds" > "$CSV_FILE"

# Determine next exercise ID
LAST_EX_ID=$(tail -n 1 "$CSV_FILE" | cut -d, -f1)

if [ "$LAST_EX_ID" = "exercise_id" ] || [ -z "$LAST_EX_ID" ]; then
    EX_NUM=1
else
    EX_NUM=$(expr "$LAST_EX_ID" + 1)
fi

EXERCISE_ID=$(printf "%02d" "$EX_NUM")

# Ask for TURN_ID with strict numeric validation
clear
while true; do
    TURN_INPUT=$(gum input --prompt "Turn ID (numbers only, e.g., 1): " --placeholder "1")

    # Check if input consists solely of digits
    if printf '%s\n' "$TURN_INPUT" | grep -Eq '^[0-9]+$'; then
        # Format as a two-digit number (e.g., 1 -> 01)
        TURN_ID=$(printf "%02d" "$TURN_INPUT")
        break
    fi

    gum style --foreground 196 "Invalid input. Turn ID must be a number." >&2
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

# Append to exercises CSV
printf '%s,%s,%s,%s,%s\n' \
    "$EXERCISE_ID" \
    "$TURN_ID" \
    "$START_TIME" \
    "$STOP_TIME" \
    "$DURATION" \
    >> "$CSV_FILE"

clear
echo
gum style --foreground 46 --bold "Exercise $EXERCISE_ID saved successfully! Duration: ${DURATION}s"
