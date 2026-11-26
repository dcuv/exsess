#!/bin/sh

SESSION_FILE=".session"
PID_FILE=".rec.pid"
ACTIVE_TURN_FILE=".active_turn"

# Default output directory for video captures
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/Videos/exsess}"

# Default camera configuration (can be overridden via environment variables)
# e.g.: VIDEO_DEV=/dev/video1 VIDEO_SIZE=1920x1080 ./scripts/rec.sh start 01
VIDEO_DEV="${VIDEO_DEV:-/dev/video1}"
VIDEO_SIZE="${VIDEO_SIZE:-1920x1080}"
FRAMERATE="${FRAMERATE:-60}"
INPUT_FORMAT="${INPUT_FORMAT:-mjpeg}"

# Audio configuration
# AUDIO_SOURCE: pulse (default for GNOME/PipeWire), alsa, or none
AUDIO_SOURCE="${AUDIO_SOURCE:-pulse}"
# AUDIO_DEV: "default" for Pulse/PipeWire default mic, or ALSA device (e.g. "hw:Camera,0" or "hw:2,0")
AUDIO_DEV="${AUDIO_DEV:-default}"

usage() {
    echo "Usage: $0 {start [turn_id]|stop|status}"
    echo ""
    echo "Commands:"
    echo "  start [turn_id]  Start recording for a given Turn ID (e.g. 01 or 1)."
    echo "                   If turn_id is omitted, checks $ACTIVE_TURN_FILE."
    echo "  stop             Stop current recording and flush MP4 cleanly."
    echo "  status           Show recording status and details."
    echo ""
    echo "Environment Variables (optional overrides):"
    echo "  OUTPUT_DIR       Destination directory (default: ~/Videos/exsess)"
    echo "  VIDEO_DEV        Camera device node (default: /dev/video1)"
    echo "  VIDEO_SIZE       Capture resolution (default: 1920x1080)"
    echo "  FRAMERATE        Capture framerate (default: 60)"
    echo "  INPUT_FORMAT     Camera input format (default: mjpeg)"
    echo "  AUDIO_SOURCE     Audio system: 'pulse' (default), 'alsa', or 'none'"
    echo "  AUDIO_DEV        Audio device name (default: 'default', or e.g. 'hw:Camera,0')"
    exit 1
}

check_session() {
    if [ ! -f "$SESSION_FILE" ]; then
        echo "Error: No active session found. Please run './scripts/ses.sh open' first." >&2
        exit 1
    fi

    SESSION_DIR=$(cat "$SESSION_FILE")
    if [ ! -d "$SESSION_DIR" ]; then
        echo "Error: Session directory does not exist: $SESSION_DIR" >&2
        exit 1
    fi

    SESSION_YML="$SESSION_DIR/session.yml"
    if [ ! -f "$SESSION_YML" ]; then
        echo "Error: session.yml not found in $SESSION_DIR" >&2
        exit 1
    fi

    SESSION_CODE=$(awk -F': ' '/^code:/ {print $2}' "$SESSION_YML")
    if [ -z "$SESSION_CODE" ]; then
        echo "Error: Could not extract session code from $SESSION_YML" >&2
        exit 1
    fi
}

start_recording() {
    check_session

    # Check if already recording
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "Already recording (PID: $PID). Run '$0 stop' first."
            exit 1
        else
            # Stale PID file
            rm -f "$PID_FILE"
        fi
    fi

    # Determine TURN_ID:
    # 1. First argument to start
    # 2. Or fallback to .active_turn file
    TURN_INPUT="$1"
    if [ -z "$TURN_INPUT" ] && [ -f "$ACTIVE_TURN_FILE" ]; then
        TURN_INPUT=$(cat "$ACTIVE_TURN_FILE")
    fi

    if [ -z "$TURN_INPUT" ]; then
        echo "Error: Turn ID is required."
        echo "Usage: $0 start <turn_id>"
        exit 1
    fi

    # Validate numeric and format to 2 digits (e.g. 1 -> 01)
    if ! printf '%s\n' "$TURN_INPUT" | grep -Eq '^[0-9]+$'; then
        echo "Error: Turn ID must be numeric (e.g. 1, 01)." >&2
        exit 1
    fi
    TURN_ID=$(printf "%02d" "$TURN_INPUT")

    # Check video device
    if [ ! -e "$VIDEO_DEV" ]; then
        echo "Error: Video device '$VIDEO_DEV' not found." >&2
        exit 1
    fi

    # Ensure session-specific output directory exists
    SESSION_OUTPUT_DIR="$OUTPUT_DIR/$SESSION_CODE"
    mkdir -p "$SESSION_OUTPUT_DIR"

    OUTPUT_FILE="$SESSION_OUTPUT_DIR/${SESSION_CODE}_${TURN_ID}.mp4"
    LOG_FILE="$SESSION_OUTPUT_DIR/${SESSION_CODE}_${TURN_ID}.ffmpeg.log"

    echo "Starting recording:"
    echo "  Session Code: $SESSION_CODE"
    echo "  Turn ID:      $TURN_ID"
    echo "  Video:        $VIDEO_DEV ($VIDEO_SIZE @ ${FRAMERATE}fps, $INPUT_FORMAT)"
    if [ "$AUDIO_SOURCE" = "none" ]; then
        echo "  Audio:        Disabled"
    else
        echo "  Audio:        $AUDIO_SOURCE ($AUDIO_DEV)"
    fi
    echo "  Output:       $OUTPUT_FILE"

    # Assemble ffmpeg arguments
    # Video input
    FFMPEG_ARGS="-f v4l2 -input_format $INPUT_FORMAT -framerate $FRAMERATE -video_size $VIDEO_SIZE -i $VIDEO_DEV"

    # Audio input (if enabled)
    if [ "$AUDIO_SOURCE" = "pulse" ]; then
        FFMPEG_ARGS="$FFMPEG_ARGS -f pulse -i $AUDIO_DEV"
        AUDIO_ENCODE="-c:a aac -b:a 192k"
    elif [ "$AUDIO_SOURCE" = "alsa" ]; then
        FFMPEG_ARGS="$FFMPEG_ARGS -f alsa -i $AUDIO_DEV"
        AUDIO_ENCODE="-c:a aac -b:a 192k"
    else
        AUDIO_ENCODE=""
    fi

    # Run ffmpeg in background
    # -nostdin: prevents ffmpeg from grabbing terminal stdin
    # -c:v libx264 -preset ultrafast -crf 23: fast, low-overhead x264 video compression
    # -c:a aac: standard AAC audio stream
    ffmpeg -nostdin -y \
        $FFMPEG_ARGS \
        -c:v libx264 -preset ultrafast -crf 23 \
        $AUDIO_ENCODE \
        "$OUTPUT_FILE" > "$LOG_FILE" 2>&1 &

    REC_PID=$!
    echo "$REC_PID" > "$PID_FILE"

    # Give ffmpeg a brief moment to check if it immediately failed (e.g. format unsupported or audio busy)
    sleep 0.5
    if ! kill -0 "$REC_PID" 2>/dev/null; then
        echo "Error: ffmpeg failed to start. Check log:" >&2
        cat "$LOG_FILE" >&2
        rm -f "$PID_FILE"
        exit 1
    fi

    echo "Recording started successfully (PID: $REC_PID)."
}

stop_recording() {
    if [ ! -f "$PID_FILE" ]; then
        echo "No recording in progress (no $PID_FILE found)."
        exit 0
    fi

    PID=$(cat "$PID_FILE")
    if ! kill -0 "$PID" 2>/dev/null; then
        echo "Process $PID is not running. Cleaning up stale PID file."
        rm -f "$PID_FILE"
        exit 0
    fi

    echo "Stopping recording (PID: $PID)..."
    # Send SIGINT (interrupt) so ffmpeg finalizes the MP4 container and audio buffers properly
    kill -INT "$PID" 2>/dev/null

    # Wait up to 10 seconds for clean exit
    WAIT_COUNT=0
    while kill -0 "$PID" 2>/dev/null; do
        sleep 0.5
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ "$WAIT_COUNT" -ge 20 ]; then
            echo "Warning: ffmpeg did not stop gracefully within 10s, forcing stop (SIGTERM)..."
            kill -TERM "$PID" 2>/dev/null
            break
        fi
    done

    rm -f "$PID_FILE"
    echo "Recording stopped."
}

status_recording() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "Recording is ACTIVE (PID: $PID)."
            if [ -f "$SESSION_FILE" ]; then
                SESSION_DIR=$(cat "$SESSION_FILE")
                echo "Session directory: $SESSION_DIR"
            fi
            exit 0
        fi
    fi
    echo "No recording in progress."
}

case "$1" in
    start)
        start_recording "$2"
        ;;
    stop)
        stop_recording
        ;;
    status)
        status_recording
        ;;
    *)
        usage
        ;;
esac
