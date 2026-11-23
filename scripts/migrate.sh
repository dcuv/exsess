#!/bin/sh

# Migration script: Add user_uuid to existing session data
# This script updates existing subjects.csv and exercises.csv files
# to include user_uuid column and creates the global data/users.csv mapping file

set -e

echo "EXSESS User UUID Migration Script"
echo "==================================="
echo

# Check if data directory exists
if [ ! -d "data" ]; then
    echo "Error: data/ directory not found. Run this script from the exsess repository root."
    exit 1
fi

# Initialize global users.csv if it doesn't exist
USERS_FILE="data/users.csv"
if [ ! -f "$USERS_FILE" ]; then
    echo "user_id,user_uuid,first_registration,last_registration" > "$USERS_FILE"
    echo "Created data/users.csv"
else
    echo "data/users.csv already exists. Skipping creation."
fi

# Initialize session.csv if it doesn't exist
SESSION_FILE="data/session.csv"
if [ ! -f "$SESSION_FILE" ]; then
    echo "session_code,session_path,created_date" > "$SESSION_FILE"
    echo "Created data/session.csv"
else
    echo "data/session.csv already exists. Skipping creation."
fi

echo

# Find all subjects.csv files in dated session directories
SUBJECTS_FILES=$(find data -type f -name "subjects.csv" 2>/dev/null)

if [ -z "$SUBJECTS_FILES" ]; then
    echo "No existing subjects.csv or exercises.csv files found. Nothing to migrate."
    exit 0
fi

SUBJECTS_MIGRATED=0
EXERCISES_MIGRATED=0
TOTAL_SESSIONS=0

echo "Found session files. Starting migration..."
echo

# Process each subjects.csv file
for SUBJECTS_CSV in $SUBJECTS_FILES; do
    SESSION_DIR=$(dirname "$SUBJECTS_CSV")
    EXERCISES_CSV="$SESSION_DIR/exercises.csv"
    SESSION_YML="$SESSION_DIR/session.yml"
    
    TOTAL_SESSIONS=$((TOTAL_SESSIONS + 1))
    
    echo "Processing session: $SESSION_DIR"
    
    # ========== RECORD SESSION IN session.csv ==========
    
    if [ -f "$SESSION_YML" ]; then
        SESSION_CODE=$(awk -F': ' '/^code:/ {print $2}' "$SESSION_YML")
        CREATED_DATE=$(awk -F': ' '/^created:/ {print $2}' "$SESSION_YML")
        
        if [ -n "$SESSION_CODE" ]; then
            # Extract relative path (YYYY/MM/DD/HHMM)
            RELATIVE_PATH=$(printf '%s' "$SESSION_DIR" | sed 's|.*/data/||')
            
            # Check if session already in session.csv
            if ! grep -q "^${SESSION_CODE}," "$SESSION_FILE" 2>/dev/null; then
                printf '%s,%s,%s\n' "$SESSION_CODE" "$RELATIVE_PATH" "$CREATED_DATE" >> "$SESSION_FILE"
                echo "  ✓ Added session $SESSION_CODE to session.csv"
            else
                echo "  ✓ Session $SESSION_CODE already in session.csv"
            fi
        fi
    fi
    
    # ========== MIGRATE subjects.csv ==========
    
    # Check if file already has user_uuid column
    HEADER=$(head -n 1 "$SUBJECTS_CSV" 2>/dev/null)
    
    if echo "$HEADER" | grep -q "user_uuid"; then
        echo "  ✓ subjects.csv already has user_uuid column"
    else
        echo "  → Migrating subjects.csv..."
        SUBJECTS_MIGRATED=$((SUBJECTS_MIGRATED + 1))
        
        # Create backup
        cp "$SUBJECTS_CSV" "${SUBJECTS_CSV}.backup"
        
        # Create new file with user_uuid column
        NEW_CSV="${SUBJECTS_CSV}.new"
        echo "turn_id,record_uuid,user_uuid,user_id,age,weight,height,gender,main_hand,share" > "$NEW_CSV"
        
        # Process each line (skip header)
        tail -n +2 "$SUBJECTS_CSV" | while IFS=',' read -r turn_id record_uuid user_id age weight height gender main_hand share; do
            # Check if user_uuid already exists in global users.csv
            existing_uuid=$(grep "^${user_id}," "$USERS_FILE" 2>/dev/null | cut -d, -f2)
            
            if [ -n "$existing_uuid" ]; then
                # Reuse existing user_uuid
                user_uuid="$existing_uuid"
                # Update last_registration timestamp
                session_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                first_reg=$(grep "^${user_id}," "$USERS_FILE" | cut -d, -f3)
                # Remove old entry and add updated one
                grep -v "^${user_id}," "$USERS_FILE" > "${USERS_FILE}.tmp"
                echo "$user_id,$user_uuid,$first_reg,$session_time" >> "${USERS_FILE}.tmp"
                mv "${USERS_FILE}.tmp" "$USERS_FILE"
            else
                # New user - create uuid
                user_uuid=$(uuidgen --random)
                session_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                echo "$user_id,$user_uuid,$session_time,$session_time" >> "$USERS_FILE"
            fi
            
            # Write to new CSV with user_uuid in correct position
            printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
                "$turn_id" \
                "$record_uuid" \
                "$user_uuid" \
                "$user_id" \
                "$age" \
                "$weight" \
                "$height" \
                "$gender" \
                "$main_hand" \
                "$share" >> "$NEW_CSV"
        done
        
        # Replace original with new file
        mv "$NEW_CSV" "$SUBJECTS_CSV"
        echo "    ✓ subjects.csv migrated"
    fi
    
    # ========== MIGRATE exercises.csv ==========
    
    if [ ! -f "$EXERCISES_CSV" ]; then
        echo "  ○ No exercises.csv found in this session"
    else
        # Get session code from session.yml
        SESSION_YML="$SESSION_DIR/session.yml"
        SESSION_CODE=$(awk -F': ' '/^code:/ {print $2}' "$SESSION_YML" 2>/dev/null)
        
        if [ -z "$SESSION_CODE" ]; then
            echo "  ✗ Warning: Could not find session code in $SESSION_YML"
            echo "    Skipping exercises.csv migration for this session"
        else
            # Check if file already has exercise_uuid column
            HEADER=$(head -n 1 "$EXERCISES_CSV" 2>/dev/null)
            
            if echo "$HEADER" | grep -q "exercise_uuid"; then
                echo "  ✓ exercises.csv already has exercise_uuid and user_uuid columns"
            else
                echo "  → Migrating exercises.csv..."
                EXERCISES_MIGRATED=$((EXERCISES_MIGRATED + 1))
                
                # Create backup
                cp "$EXERCISES_CSV" "${EXERCISES_CSV}.backup"
                
                # Create new file with exercise_uuid and user_uuid columns
                NEW_CSV="${EXERCISES_CSV}.new"
                echo "exercise_id,exercise_uuid,turn_id,user_uuid,start_time,stop_time,duration_seconds" > "$NEW_CSV"
                
                # Process each line (skip header) without subshell
                EX_NUM=1
                while IFS=',' read -r exercise_id turn_id start_time stop_time duration_seconds; do
                    # Generate exercise_uuid with session code as prefix
                    exercise_uuid="${SESSION_CODE}_$(printf '%02d' "$EX_NUM")"
                    
                    # Look up user_uuid from subjects.csv by turn_id
                    user_uuid=$(grep "^$turn_id," "$SUBJECTS_CSV" 2>/dev/null | cut -d, -f3)
                    
                    if [ -z "$user_uuid" ]; then
                        echo "Warning: Could not find user_uuid for turn_id $turn_id in $SUBJECTS_CSV" >&2
                        user_uuid="unknown"
                    fi
                    
                    # Write to new CSV
                    printf '%s,%s,%s,%s,%s,%s,%s\n' \
                        "$exercise_id" \
                        "$exercise_uuid" \
                        "$turn_id" \
                        "$user_uuid" \
                        "$start_time" \
                        "$stop_time" \
                        "$duration_seconds" >> "$NEW_CSV"
                    
                    EX_NUM=$((EX_NUM + 1))
                done < <(tail -n +2 "$EXERCISES_CSV")
                
                # Replace original with new file
                mv "$NEW_CSV" "$EXERCISES_CSV"
                echo "    ✓ exercises.csv migrated with exercise_uuid"
            fi
        fi
    fi
    
    echo
done

echo
echo "Migration Complete!"
echo "==================="
echo "Sessions processed: $TOTAL_SESSIONS"
echo "subjects.csv files migrated: $SUBJECTS_MIGRATED"
echo "exercises.csv files migrated: $EXERCISES_MIGRATED"
echo
echo "✓ All CSV files now include user_uuid"
echo "✓ data/users.csv updated with user mappings"
echo

echo "Next steps:"
echo "1. Verify data/users.csv has all participants"
echo "2. Check exercises.csv has user_uuid column"
echo "3. Test that ex.sh works correctly"
echo
echo "Backups of original files saved as *.backup"
