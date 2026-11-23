# Implementation Plan: Persistent User UUID for Cross-Session Identification

## Objective
Add a persistent user identifier that remains constant across multiple sessions for the same person, enabling ML training models to track individual participants over time while maintaining session-specific recording data.

## Current State

**subjects.csv (session-specific):**
```
turn_id,record_uuid,user_id,age,weight,height,gender,main_hand,share
01,<UUID v7>,12345678Z,27,75,175,Male,Right,Yes
```

- `record_uuid`: Unique identifier for the recorded data in this session
- `user_id`: Participant's identifier (can repeat across sessions)
- Other fields: Participant demographics (can change per session)

## Proposed Solution

### 1. New Global Mapping File: `data/users.csv`

**Location:** At `data/users.csv` (persistent across all sessions)

**Format:**
```csv
user_id,user_uuid,first_registration,last_registration
12345678Z,<UUID v7>,2026-11-23T10:05:30Z,2026-11-23T10:05:30Z
87654321A,<UUID v7>,2026-11-20T14:22:15Z,2026-11-23T11:30:00Z
```

**Fields:**
- `user_id`: Participant's ID (primary key)
- `user_uuid`: Persistent UUID (generated once, never changes)
- `first_registration`: Timestamp of first registration across all sessions
- `last_registration`: Timestamp of most recent registration (updates each session)

### 2. Changes to `subjects.csv`

**Add new column `user_uuid`:**
```csv
turn_id,record_uuid,user_uuid,user_id,age,weight,height,gender,main_hand,share
01,<record_uuid>,<user_uuid>,12345678Z,27,75,175,Male,Right,Yes
```

**Purpose:** Denormalizes user_uuid into session data for easier correlation with exercise records

### 3. Changes to `exercises.csv`

**Add new column `user_uuid` for direct video/IMU labeling:**
```csv
exercise_id,turn_id,user_uuid,start_time,stop_time,duration_seconds
01,01,<user_uuid>,2026-11-23T10:05:30Z,2026-11-23T10:06:45Z,75
```

**Purpose:** Enables direct export of exercises.csv to external video/IMU labeling tools without needing to join with subjects.csv. When you extract this CSV from the VeraCrypt volume, it contains everything needed to label video frames and sensor data with user identification.

### 3. Workflow Changes

#### First Registration of a User

```
new.sh execution:
  1. User enters DNI/User ID
  2. Check if user_id exists in data/users.csv
     → If NOT found:
        - Generate new user_uuid (UUIDv7)
        - Create entry in data/users.csv
        - Use user_uuid in subjects.csv
     → If FOUND:
        - Retrieve existing user_uuid
        - Update last_registration timestamp
        - Use user_uuid in subjects.csv
  3. Add record to subjects.csv with user_uuid
```

#### Subsequent Sessions with Same User

```
new.sh execution:
  1. User enters same DNI/User ID
  2. Check data/users.csv
     → User found
     - Reuse existing user_uuid
     - Update last_registration timestamp
  3. Add new record to subjects.csv with same user_uuid
```

## Implementation Steps

### Phase 1: Create Data Structure (new.sh and ex.sh modifications)

**Changes to `new.sh`:**

1. **Add function to manage user_uuid:**
   ```bash
   get_or_create_user_uuid() {
       user_id="$1"
       users_file="data/users.csv"
       
       # Initialize file if needed
       if [ ! -f "$users_file" ]; then
           echo "user_id,user_uuid,first_registration,last_registration" > "$users_file"
       fi
       
       # Check if user exists
       existing_uuid=$(grep "^${user_id}," "$users_file" | cut -d, -f2)
       
       if [ -n "$existing_uuid" ]; then
           # User exists - update last_registration
           update_last_registration "$user_id"
           echo "$existing_uuid"
       else
           # New user - create entry
           user_uuid=$(uuidgen --time-v7)
           timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
           echo "$user_id,$user_uuid,$timestamp,$timestamp" >> "$users_file"
           echo "$user_uuid"
       fi
   }
   ```

2. **Modify subjects.csv header to include user_uuid:**
   ```bash
   # Create CSV if needed with new column
   [ -f "$CSV_FILE" ] || \
       echo "turn_id,record_uuid,user_uuid,user_id,age,weight,height,gender,main_hand,share" > "$CSV_FILE"
   ```

3. **Call function after user enters user_id:**
   ```bash
   USER_UUID=$(get_or_create_user_uuid "$USER_ID")
   ```

4. **Write user_uuid to subjects.csv:**
   ```bash
   printf '%s,%s,%s,%s,...' \
       "$TURN_ID" \
       "$RECORD_UUID" \
       "$USER_UUID" \
       "$USER_ID" \
       ...
   ```

**Changes to `ex.sh`:**

1. **Modify exercises.csv header to include user_uuid:**
   ```bash
   # Create CSV if needed with new column
   [ -f "$CSV_FILE" ] || \
       echo "exercise_id,turn_id,user_uuid,start_time,stop_time,duration_seconds" > "$CSV_FILE"
   ```

2. **After Turn ID validation, lookup user_uuid from subjects.csv:**
   ```bash
   # Get user_uuid from subjects.csv by turn_id
   USER_UUID=$(grep "^$TURN_ID," "$SESSION_DIR/subjects.csv" | cut -d, -f3)
   
   if [ -z "$USER_UUID" ]; then
       gum style --foreground 196 "Error: Could not find user_uuid for Turn ID $TURN_ID"
       exit 1
   fi
   ```

3. **Write user_uuid to exercises.csv:**
   ```bash
   printf '%s,%s,%s,%s,%s,%s\n' \
       "$EXERCISE_ID" \
       "$TURN_ID" \
       "$USER_UUID" \
       "$START_TIME" \
       "$STOP_TIME" \
       "$DURATION" \
       >> "$CSV_FILE"
   ```

### Phase 2: Handle Existing Data (migration)

**For existing subjects.csv without user_uuid:**

1. Create migration script: `scripts/migrate-users.sh`
   - Read all user_ids from existing subjects.csv files
   - Generate user_uuid for each unique user_id
   - Create data/users.csv
   - Update subjects.csv files to include user_uuid column

2. Run migration once after deployment

### Phase 3: Link with Exercise Data

**In ex.sh:**
- No changes needed initially
- Future: Can optionally store user_uuid in exercises.csv for direct linking

**Data Correlation:**
```
exercises.csv → (turn_id) → subjects.csv → (user_uuid) → data/users.csv
                                              ↓
                                         ML Training: Same user_uuid across sessions
```

## File Structure After Implementation

```
data/
├── users.csv                    # NEW: Global user UUID mapping
├── 2026/11/23/1003/
│   ├── session.yml
│   ├── subjects.csv             # MODIFIED: Added user_uuid column
│   └── exercises.csv
└── 2026/11/23/1004/
    ├── session.yml
    ├── subjects.csv             # Same user_uuid for returning participants
    └── exercises.csv
```

## Data Flow Diagram

```
User Registration (new.sh)
  ↓
Enter User ID (e.g., "12345678Z")
  ↓
Check data/users.csv
  ├─ User found? → Retrieve user_uuid, update timestamp
  └─ New user?   → Generate user_uuid, create entry
  ↓
Write to session's subjects.csv with user_uuid
  ↓
Exercise Recording (ex.sh)
  ↓
Enter Turn ID
  ↓
Lookup user_uuid from subjects.csv
  ↓
Record exercise with user_uuid, start_time, stop_time
  ↓
Write to exercises.csv with user_uuid
  ↓
EXPORT: exercises.csv → External tools
  ├─ Video labeling: Use user_uuid + timestamp to label video frames
  ├─ IMU data labeling: Use user_uuid + timestamp to label sensor readings
  └─ ML training: User UUID enables cross-session participant tracking
```

## Export Workflow for Video/IMU Labeling

```
Inside VeraCrypt Volume:
├── data/users.csv                 (global user registry)
├── 2026/11/23/1003/
│   ├── subjects.csv               (session participants)
│   └── exercises.csv ◄─ THIS FILE (timestamp + user_uuid)
        ↓ EXPORT
        
Outside VeraCrypt:
├── exercises.csv (copied to external storage)
├── video_data/
│   ├── 2026-11-23_1003_participant_<user_uuid>_frames.mp4
│   └── ...
├── imu_data/
│   ├── 2026-11-23_1003_participant_<user_uuid>_imu.csv
│   └── ...
└── labeling_script.py
    Uses: user_uuid, start_time, stop_time
    Extracts video frames and sensor data for labeling
```

**Key Advantage:** When you export `exercises.csv`, you have:
- `user_uuid`: Direct participant identifier (same across sessions)
- `start_time`, `stop_time`: Exact temporal bounds for data extraction
- No need to join with other files in external tools

## Benefits

1. **User Tracking**: Same `user_uuid` across sessions identifies the same person
2. **ML Training**: Persistent ID enables supervised learning with multi-session data
3. **Data Integrity**: `first_registration` and `last_registration` track participation timeline
4. **Self-Contained Export**: `exercises.csv` has everything needed for video/IMU labeling (user_uuid + timestamps)
5. **No External Joins**: External labeling tools don't need to reference subjects.csv or users.csv
6. **Backward Compatible**: Doesn't break existing code, only adds new column

## Testing Strategy

1. **First Registration**: New user creates user_uuid ✓
2. **Second Session**: Same user retrieves same user_uuid ✓
3. **Multiple Users**: Each gets unique user_uuid ✓
4. **Data Correlation**: Can join subjects.csv → users.csv → exercises ✓
5. **Migration**: Existing data converts properly ✓

## Considerations

- **File Location**: `data/users.csv` persists across sessions (or inside VeraCrypt volume?)
  - **Recommendation**: Place inside mounted VeraCrypt volume at same level as dated folders
  - Alternative: Place at unencrypted project level if user IDs should be tracked externally

- **Performance**: For thousands of users, consider binary format or database
  - Current CSV approach sufficient for typical experimental sessions (10-100 participants)

- **Privacy**: user_uuid is anonymous but stable
  - user_id (DNI) remains visible in session data
  - Consider if user_uuid needs same encryption/security as user_id

## Questions for Review

1. Should `data/users.csv` live **inside** (mounted VeraCrypt) or **outside** the volume?
2. Should we store user_uuid in exercises.csv too, or only derive it via subjects.csv?
3. Do we need additional metadata in users.csv (email, participant group, etc.)?
4. Should there be an admin script to view/manage users across all sessions?

