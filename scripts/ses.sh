#!/bin/sh

SESSION_FILE=".session"

create_session() {
    UUID=$(uuidgen --time-v7)
    CODE=$(tr -dc 'A-Z0-9' </dev/urandom | head -c 6)
    CREATED_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    DIR="$(pwd)/data/sessions/$CODE"
    mkdir -p "$DIR"

    cat > "$DIR/session.yml" <<EOF
id: $UUID
code: $CODE
created: $CREATED_DATE
description: ""
location: ""
EOF

    # Record session in data/sessions.csv
    SESSIONS_CSV="$(pwd)/data/sessions.csv"
    if [ ! -f "$SESSIONS_CSV" ]; then
        echo "session_code,session_path,created_date" > "$SESSIONS_CSV"
    fi
    # Relative path from repository data root
    RELATIVE_PATH="sessions/$CODE"
    printf '%s,%s,%s\n' "$CODE" "$RELATIVE_PATH" "$CREATED_DATE" >> "$SESSIONS_CSV"

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

    # Get creation date from session.yml (ISO 8601: YYYY-MM-DDTHH:MM:SSZ)
    CREATED_STR=$(awk -F': ' '/^created:/ {print $2}' "$SESSION_YML")
    if [ -n "$CREATED_STR" ]; then
        # Extract YYMMDD from created timestamp (e.g. 2026-11-24... -> 261124)
        YYMMDD=$(printf '%s' "$CREATED_STR" | sed -E 's/^[0-9]{2}([0-9]{2})-([0-9]{2})-([0-9]{2}).*/\1\2\3/')
    fi

    # Fallback to current date if not found in session.yml
    if [ -z "$YYMMDD" ] || [ $(printf '%s' "$YYMMDD" | wc -c) -ne 6 ]; then
        YYMMDD=$(date +%y%m%d)
    fi

    # SESSID as the 6-character alphanumeric code from session.yml
    SESSID=$(awk -F': ' '/^code:/ {print $2}' "$SESSION_YML")
    if [ -z "$SESSID" ]; then
        SESSID=$(basename "$SESSION_DIR")
    fi

    DEST_DIR="$(pwd)/data"
    mkdir -p "$DEST_DIR"

    DEST_FILE="$DEST_DIR/${YYMMDD}_${SESSID}.exercises.csv"

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
