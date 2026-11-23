#!/bin/sh

SESSION_FILE=".session"

create_session() {
   YEAR=$(date +%Y)
   MONTH=$(date +%m)
   DAY=$(date +%d)
   SESSION=$(date +%H%M)
   DIR="$(pwd)/data/$YEAR/$MONTH/$DAY/$SESSION"
   
   mkdir -p "$DIR"
   
   UUID=$(uuidgen --time-v7)
   CODE=$(tr -dc 'A-Z0-9' </dev/urandom | head -c 6)
   cat > "$DIR/session.yml" <<EOF
id: $UUID
code: $CODE
created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
description: ""
location: ""
EOF

   # Record session in data/session.csv
   SESSION_CSV="$(pwd)/data/session.csv"
   if [ ! -f "$SESSION_CSV" ]; then
       echo "session_code,session_path,created_date" > "$SESSION_CSV"
   fi
   # Extract relative path from full path (remove leading "$(pwd)/")
   RELATIVE_PATH="$YEAR/$MONTH/$DAY/$SESSION"
   printf '%s,%s,%s\n' "$CODE" "$RELATIVE_PATH" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$SESSION_CSV"

   printf '%s\n' "$DIR" > "$SESSION_FILE"
   echo "Session opened:"
   echo "$DIR"
   echo "Code: $CODE"
}

export_exercises() {
    SESSION_DIR="$1"
    EX_CSV="$SESSION_DIR/exercises.csv"

    if [ ! -f "$EX_CSV" ]; then
        echo "Note: No exercises.csv found in session directory. Skipping export."
        return 0
    fi

    SESSION_YML="$SESSION_DIR/session.yml"

    # Extract YY, MM, DD from the path (.../data/YYYY/MM/DD/HHMM)
    DAY=$(basename "$(dirname "$SESSION_DIR")")
    MONTH=$(basename "$(dirname "$(dirname "$SESSION_DIR")")")
    YEAR_FULL=$(basename "$(dirname "$(dirname "$(dirname "$SESSION_DIR")")")")
    YY=$(printf '%s' "$YEAR_FULL" | cut -c 3-4)

    # Option A: SESSID as the 6-character alphanumeric code from session.yml
    SESSID=$(awk -F': ' '/^code:/ {print $2}' "$SESSION_YML")

    DEST_DIR="$(pwd)/data"
    mkdir -p "$DEST_DIR"

    DEST_FILE="$DEST_DIR/${YY}${MONTH}${DAY}_${SESSID}.exercises.csv"

    cp "$EX_CSV" "$DEST_FILE"
    echo "Copied exercises.csv to $DEST_FILE"
}

close_session() {
    if [ -f "$SESSION_FILE" ]; then
        SESSION_DIR=$(cat "$SESSION_FILE")

        export_exercises "$SESSION_DIR"

        rm -f "$SESSION_FILE"
        echo "Session closed."
    else
        echo "No active session."
    fi
}

status_session() {
        if [ ! -f "$SESSION_FILE" ]; then
            echo "No active session."
            exit 1
        fi

        SESSION_DIR=$(cat "$SESSION_FILE")
        SESSION_YML="$SESSION_DIR/session.yml"

        echo "Session directory: $SESSION_DIR"
        echo

        awk -F': ' '
            /^id:/          { print "ID:          " $2 }
            /^code:/        { print "Code:        " $2 }
            /^created:/     { print "Created:     " $2 }
            /^description:/ { print "Description: " substr($0, index($0,$2)) }
            /^location:/    { print "Location:    " substr($0, index($0,$2)) }
        ' "$SESSION_YML"
}

path_session() {
        if [ ! -f "$SESSION_FILE" ]; then
            echo "No active session." >&2
            exit 1
        fi

        cat "$SESSION_FILE"
}

case "$1" in
    open)
        if [ -f "$SESSION_FILE" ]; then
            echo "Session already active:"
            cat "$SESSION_FILE"
            exit 1
        fi

        create_session
        ;;

    close)
        close_session
        ;;

    status)
        status_session
        ;;

    path)
        path_session
        ;;

    *)
        echo "Usage: $0 {open|close|status|path}"
        exit 1
        ;;
esac
