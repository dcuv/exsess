#!/bin/bash

SESSION_FILE=".session"
ACTIVE_TURN_FILE=".active_turn"
SCRIPT_DIR=$(dirname "$0")
REC_SCRIPT="$SCRIPT_DIR/rec.sh"
RECORD_VIDEO=""

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --rec      Automatically record video without prompting"
    echo "      --no-rec   Skip video recording without prompting"
    echo "  -h, --help     Show this help message"
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        -r|--rec)
            RECORD_VIDEO="yes"
            shift
            ;;
        --no-rec)
            RECORD_VIDEO="no"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1
            ;;
    esac
done

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

# Ask whether to record video if not specified via CLI flags
if [ -z "$RECORD_VIDEO" ]; then
    if gum confirm "Record video for Turn ID $TURN_ID?"; then
        RECORD_VIDEO="yes"
    else
        RECORD_VIDEO="no"
    fi
fi

RECORDING_ACTIVE=0
printf '%s\n' "$TURN_ID" > "$ACTIVE_TURN_FILE"

cleanup() {
    stty echo 2>/dev/null || true
    if [ "$RECORDING_ACTIVE" -eq 1 ] && [ -x "$REC_SCRIPT" ]; then
        "$REC_SCRIPT" stop
        RECORDING_ACTIVE=0
    fi
    rm -f "$ACTIVE_TURN_FILE"
}

trap 'cleanup; exit 130' INT TERM

if [ "$RECORD_VIDEO" = "yes" ]; then
    if [ ! -x "$REC_SCRIPT" ]; then
        gum style --foreground 196 "Recording script not found or not executable: $REC_SCRIPT" >&2
        gum confirm "Continue exercise without video?" || { cleanup; exit 1; }
    elif "$REC_SCRIPT" start "$TURN_ID"; then
        RECORDING_ACTIVE=1
    else
        gum style --foreground 196 "Failed to start video recording." >&2
        gum confirm "Continue exercise without video?" || { cleanup; exit 1; }
    fi
fi

clear
gum style --bold "Exercise $EXERCISE_ID Started for Turn ID: $TURN_ID"
if [ "$RECORDING_ACTIVE" -eq 1 ]; then
    gum style --foreground 196 --bold "● REC: Video recording active (${SESSION_CODE}_${TURN_ID}.mp4)"
fi
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

# Record stop time immediately before stopping ffmpeg
STOP_EPOCH=$(date +%s)
STOP_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DURATION=$((STOP_EPOCH - START_EPOCH))

VIDEO_RECORDED=$RECORDING_ACTIVE
cleanup

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
if [ "$VIDEO_RECORDED" -eq 1 ]; then
    gum style --foreground 46 "Video recording saved (${SESSION_CODE}_${TURN_ID}.mp4)."
fi
