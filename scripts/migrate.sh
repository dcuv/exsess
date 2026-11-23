#!/bin/sh

# Migration script: Add user_uuid to existing session data
# This script updates existing subjects.csv files to include user_uuid column
# and creates the global data/users.csv mapping file

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

echo

# Find all subjects.csv files in dated session directories
SUBJECTS_FILES=$(find data -type f -name "subjects.csv" 2>/dev/null)

if [ -z "$SUBJECTS_FILES" ]; then
    echo "No existing subjects.csv files found. Nothing to migrate."
    exit 0
fi

MIGRATED_COUNT=0
TOTAL_COUNT=0

echo "Found subjects.csv files. Starting migration..."
echo

# Process each subjects.csv file
for SUBJECTS_CSV in $SUBJECTS_FILES; do
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    SESSION_DIR=$(dirname "$SUBJECTS_CSV")
    
    echo "Processing: $SUBJECTS_CSV"
    
    # Check if file already has user_uuid column
    HEADER=$(head -n 1 "$SUBJECTS_CSV")
    
    if echo "$HEADER" | grep -q "user_uuid"; then
        echo "  ✓ Already has user_uuid column. Skipping."
        echo
        continue
    fi
    
    MIGRATED_COUNT=$((MIGRATED_COUNT + 1))
    
    # Create backup
    cp "$SUBJECTS_CSV" "${SUBJECTS_CSV}.backup"
    echo "  → Created backup: ${SUBJECTS_CSV}.backup"
    
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
            user_uuid=$(uuidgen --time-v7)
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
    echo "  ✓ Migrated: Added user_uuid column to $TOTAL_COUNT records"
    
    echo
done

echo
echo "Migration Complete!"
echo "==================="
echo "Migrated: $MIGRATED_COUNT file(s)"
echo "Total processed: $TOTAL_COUNT file(s)"
echo
echo "✓ All subjects.csv files now include user_uuid"
echo "✓ data/users.csv updated with user mappings"
echo

echo "Next steps:"
echo "1. Test that ex.sh works correctly with exercises.csv"
echo "2. Verify data/users.csv has all participants"
echo "3. Check that user_uuid appears in exercises.csv when recording"
echo
echo "Backups of original files saved as *.backup"
