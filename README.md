# EXSESS - Experimentation Season Control System

A collection of shell scripts for managing secure scientific experiments within an encrypted VeraCrypt volume. EXSESS controls experimentation sessions, registers participants, and records precise temporal markers that are used to label and synchronize experimental data (video recordings and sensor readings).

## Project Structure

### Outside VeraCrypt Volume (Unencrypted)
```
exsess/
├── extra/
│   └── vc.sh       # Volume mount/unmount script (stays OUTSIDE volume)
└── README.md       # This file
```

### Inside VeraCrypt Volume (Encrypted)
```
exsess/ (mounted at ~/mnt/vera)
├── scripts/
│   ├── ses.sh      # Session management (open, close, status)
│   ├── new.sh      # Register new participant (interactive form)
│   ├── user.sh     # Quick user registration (simple input)
│   └── ex.sh       # Exercise timer and temporal logging
└── data/           # Session data storage with experimental records
```

## Encrypted Storage Architecture

**All experimental scripts and data are stored within an encrypted VeraCrypt volume** for secure handling of sensitive experimental records and sensor data. The volume must be mounted before accessing the scripts.

**Key Points:**
- `extra/vc.sh` lives **outside** the volume and serves as the access mechanism
- `scripts/` and `data/` folders live **inside** the encrypted volume
- Mount the volume using `extra/vc.sh` before running any experiments
- Unmount when finished to re-encrypt all data

**Configuration in `extra/vc.sh`:**
```bash
VOLUME="$HOME/subes.hc"        # Path to VeraCrypt container file
MAPPER="vc"                     # Device mapper name
MOUNTPOINT="$HOME/mnt/vera"    # Where volume mounts
```

Customize these paths in `extra/vc.sh` to match your environment.

## Prerequisites

- **VeraCrypt** - Encryption software for creating/mounting volumes
- **cryptsetup** - Command-line tool for managing encrypted volumes (used by `vc.sh`)
- `gum` - Terminal UI/UX library for interactive prompts (used by `new.sh` and `ex.sh`)
- `uuidgen` - UUID generation utility (used by `ses.sh`, `new.sh`, and `user.sh`)
- Standard shell utilities: `date`, `awk`, `grep`, `tr`
- **sudo** access - Required for mounting/unmounting encrypted volumes

### Installation

**VeraCrypt & cryptsetup:**
- **Ubuntu/Debian**: `sudo apt-get install veracrypt cryptsetup`
- **macOS**: `brew install veracrypt`
- **Other**: See [VeraCrypt documentation](https://www.veracrypt.fr/)

Install `gum`:
- **Ubuntu/Debian**: `sudo apt-get install gum`
- **macOS**: `brew install gum`
- **Other**: See [charm.sh/gum](https://github.com/charmbracelet/gum)

## Scripts

### `extra/vc.sh` - VeraCrypt Volume Management

**Location:** Outside the VeraCrypt volume (stays unencrypted for access control)

Mounts and unmounts the encrypted VeraCrypt volume containing all experimental scripts and data.

**Usage:**
```bash
./extra/vc.sh {mount|umount|status}
```

**Configuration (edit `extra/vc.sh` to customize):**
```bash
VOLUME="$HOME/subes.hc"        # VeraCrypt container file path
MAPPER="vc"                     # Device mapper identifier
MOUNTPOINT="$HOME/mnt/vera"    # Mount location
```

**Commands:**

- **`mount`** - Mount the VeraCrypt volume
  - Prompts for passphrase (interactive)
  - Makes scripts and data accessible at `$MOUNTPOINT`
  - Requires sudo access

- **`umount`** - Safely unmount the VeraCrypt volume
  - Closes all file handles
  - Re-encrypts all data at rest
  - Requires sudo access

- **`status`** - Check if volume is currently mounted
  - Shows mount point and disk usage if mounted
  - Shows "Not mounted" if volume is closed

**Security Workflow:**
```bash
# Start session
./extra/vc.sh mount
# ... run experiments using scripts inside volume ...
# End session
./extra/vc.sh umount
```

**Security Note:** 
- Always unmount the volume when finished to ensure experimental data remains encrypted
- Keep `extra/vc.sh` secure—it's the key to accessing sensitive experimental data
- The script requires `sudo` for cryptographic operations

### `ses.sh` - Session Management

Manages experiment sessions with hierarchical directory structure and metadata.

**Usage:**
```bash
./scripts/ses.sh {open|close|status|path}
```

**Commands:**

- **`open`** - Create a new session
  - Generates a session directory: `data/YYYY/MM/DD/HHMM/`
  - Creates `session.yml` with:
    - Unique UUID (time-based v7)
    - 6-character alphanumeric code
    - Creation timestamp
    - Placeholder fields for description and location
  - Stores session path in `.session` file (active session marker)

- **`close`** - Close the current session
  - Exports `exercises.csv` to `data/` as `YYMMDD_CODE.exercises.csv`
  - Removes `.session` marker file

- **`status`** - Display current session information
  - Shows session directory, ID, code, creation time, description, and location

- **`path`** - Print the current session directory path
  - Useful for scripting and automation

### `new.sh` - Interactive Participant Registration

Comprehensive participant registration with form-based input using `gum`. Registers experimental subjects with demographic and consent information.

**Usage:**
```bash
./scripts/new.sh
```

**Collected Data:**
- **DNI** - National ID (required)
- **Age** - Years (numeric, optional)
- **Height** - Centimeters (numeric, optional)
- **Weight** - Kilograms (numeric, optional)
- **Gender** - Choice: Male, Female, Other
- **Main Hand** - Choice: Right, Left
- **Share Data** - Consent: Yes, No

**Output:**
- Appends record to `session_dir/subjects.csv`
- Displays assigned Turn ID (formatted as 2 digits, e.g., "01", "02")
- Generates time-based UUID v7 for record identification

### `user.sh` - Quick User Registration

Lightweight participant registration using simple `read` input (no `gum` dependency).

**Usage:**
```bash
./scripts/user.sh
```

**Collected Data:**
- User ID (required)
- Age (years, optional)
- Weight (kg, optional)
- Height (cm, optional)
- Gender (optional)
- Main Hand (optional)

**Output:**
- Appends record to `session_dir/subjects.csv`
- Displays assigned Turn ID
- Generates time-based UUID v7 for record identification

### `ex.sh` - Exercise/Task Timer & Temporal Logging

Records the precise start and stop times when each participant performs their assigned experimental task. This temporal data is critical for synchronizing with video recordings and sensor data collected during the experiment.

**Usage:**
```bash
./scripts/ex.sh
```

**Interactive Flow:**
1. Prompts for Turn ID (numeric input only)
2. Displays countdown timer (HH:MM:SS format)
3. Press 'q' or 'Q' to stop the timer
4. Automatically records elapsed time with ISO 8601 timestamps

**Output:**
- Appends record to `session_dir/exercises.csv` with:
  - `exercise_id` - Auto-incrementing (01, 02, 03...)
  - `turn_id` - Associated participant turn
  - `start_time` - ISO 8601 timestamp (UTC) — when participant began task
  - `stop_time` - ISO 8601 timestamp (UTC) — when participant finished task
  - `duration_seconds` - Elapsed time in seconds

**Data Labeling:** Use `start_time` and `stop_time` to label corresponding video frames and sensor readings collected during the participant's performance.

## Data Files

### Session Metadata (`session.yml`)
```yaml
id: <UUID v7>
code: <6-character alphanumeric>
created: <ISO 8601 timestamp>
description: ""
location: ""
```

### Subjects Data (`subjects.csv`)
```
turn_id,record_uuid,user_id,age,weight,height,gender,main_hand,share
01,<UUID v7>,12345678Z,27,75,175,Male,Right,Yes
```

### Exercises Data (`exercises.csv`)
```
exercise_id,turn_id,start_time,stop_time,duration_seconds
01,01,2026-11-23T10:05:30Z,2026-11-23T10:06:45Z,75
```

## Workflow Example

1. **Mount the VeraCrypt volume (from project root):**
   ```bash
   ./extra/vc.sh mount
   ```
   Volume decrypts and mounts at `~/mnt/vera`
   Scripts and data are now accessible

2. **Navigate to mounted volume and start an experiment session:**
   ```bash
   cd ~/mnt/vera
   ./scripts/ses.sh open
   ```
   Output: `data/2026/11/23/1003` with code `A1B2C3`

3. **Register first participant:**
   ```bash
   ./scripts/new.sh
   ```
   Participant assigned Turn ID: `01`

4. **Start recording video and sensor data**
   - Begin collecting video footage and sensor readings
   - Note that `ex.sh` will log precise timestamps

5. **Record participant's task execution:**
   ```bash
   ./scripts/ex.sh
   ```
   Enter Turn ID: `01`, press 'q' when task completes
   - Logs: `start_time=2026-11-23T10:05:30Z`, `stop_time=2026-11-23T10:06:45Z`

6. **Use timestamps to label data**
   - Frame extraction: Extract video frames from 10:05:30 to 10:06:45 UTC
   - Sensor sync: Isolate sensor data within the same time window
   - Annotation: Tag extracted data with participant Turn ID and Exercise ID

7. **Register additional participants and repeat steps 3-6**

8. **Check session summary:**
   ```bash
   ./scripts/ses.sh status
   ```

9. **Close the experiment session:**
   ```bash
   ./scripts/ses.sh close
   ```
   Exercises exported to: `data/261123_A1B2C3.exercises.csv`

10. **Unmount the VeraCrypt volume (from project root):**
    ```bash
    ./extra/vc.sh umount
    ```
    Data is now encrypted and secure.

## Directory Structure Created

```
data/
├── 2026/
│   └── 11/
│       └── 23/
│           └── 1003/
│               ├── session.yml
│               ├── subjects.csv
│               └── exercises.csv
└── 261123_A1B2C3.exercises.csv  (exported after close)
```

## Notes

- **VeraCrypt Security:** Always mount before use and unmount when finished
- A `.session` file tracks the currently active experiment session
- Scripts prevent overlapping sessions (can't open while one is active)
- All timestamps are in ISO 8601 format (UTC) for precise cross-system synchronization
- Turn IDs are zero-padded to 2 digits (01, 02, 03...) for consistent file naming
- Exercise IDs auto-increment per session
- UUID v7 enables natural time-based sorting of records
- Input validation differs between scripts (gum-based vs. simple read)
- **Temporal Precision:** Timestamps recorded by `ex.sh` are the reference points for labeling video frames and sensor data
- **Data Integrity:** Store the exported CSV files (`*.exercises.csv`, `subjects.csv`) with your video/sensor recordings for complete traceability

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "No active session" | Run `./scripts/ses.sh open` first |
| Session already active | Run `./scripts/ses.sh close` to close the current session |
| `gum: command not found` | Install gum (see Prerequisites) or use `user.sh` instead of `new.sh` |
| `uuidgen: command not found` | Install uuid-runtime (Ubuntu/Debian) or uuid package for your OS |
| `cryptsetup: command not found` | Install cryptsetup (see Prerequisites) |
| "Permission denied" when mounting | Ensure you have sudo access; `extra/vc.sh` requires root privileges |
| Volume already mounted | Run `./extra/vc.sh umount` first, then try again |
| Timer not responding to 'q' | Ensure terminal is in proper state; use Ctrl+C as backup |
| "Device or resource busy" on unmount | Close all file handles: `lsof +D ~/mnt/vera` to find open files |

## License

[Add your license here]

## Author

[Add author information here]
