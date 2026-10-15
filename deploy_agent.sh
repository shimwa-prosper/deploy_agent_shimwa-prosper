#!/usr/bin/env bash

# Global configuration variables
TEMPLATES_DIR="templates"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
# Interrupt handler: zips and removes any half-finished deployment
cleanup_on_interrupt() {
    echo -e "\n\n[!] Deployment interrupted by user via SIGINT/SIGTSTP signal."
    if [ ! -z "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
        echo "Packaging incomplete workspace for structural evaluation..."
        zip -r "${PROJECT_DIR}_archive.zip" "$PROJECT_DIR" > /dev/null 2>&1
        echo "Cleaning up loose directories to prevent workspace clutter..."
        rm -rf "$PROJECT_DIR"
    fi
    echo "Cleanup operations finished. Session closed cleanly."
    exit 1
}


# 2. FEATURE 2: STANDALONE RUN MODE

run_application() {
    local TARGET_DIR="$1"
    
    # When launched directly from the menu, ask which workspace to run
    if [ -z "$TARGET_DIR" ]; then
        read -p "Enter target instance workspace unique identifier to execute: " DIR_SUFFIX
        if [ -z "$DIR_SUFFIX" ]; then
            echo "Error: Work spapce unique identifier cannot be blank." >&2
            return 1
        fi
        TARGET_DIR="attendance_tracker_${DIR_SUFFIX}"
    fi

    # Make sure the chosen workspace and its attendance file actually exist
    if [ ! -d "$TARGET_DIR" ] || [ ! -f "$TARGET_DIR/attendance_checker.py" ]; then
        echo "Error: Target path '$TARGET_DIR' is not valid (^o^)" >&2
        return 1
    fi

    echo "Teleporting shell context into execution space..."
    cd "$TARGET_DIR" || return 1
    
    echo "Opening the interactive Python tracking app..."
    python3 attendance_checker.py
    
    cd ..
    echo "Python application closed safely. Returned back to master agent context."
}


# 3. FEATURE 3: LOG ARCHIVING
archive_logs() {
    read -p "Specify targeted instance workspace unique identifier to archive (eg., v1: " DIR_SUFFIX
    if [ -z "$DIR_SUFFIX" ]; then
        echo "Error: Selection cannot be blank." >&2
        return 1
    fi
    
    local TRK_DIR="attendance_tracker_${DIR_SUFFIX}"
    if [ ! -d "$TRK_DIR" ]; then
        echo "Error: Workspace directory '$TRK_DIR' does not exist." >&2
        return 1
    fi

    local REP_DIR="$TRK_DIR/reports"
    local ARCH_ATT="$TRK_DIR/archives/attendance"
    local ARCH_ABS="$TRK_DIR/archives/absent"

    echo "Scanning application telemetry reports path..."

    # Archive the attendance log (just print a notice if it is missing)
    if [ -f "$REP_DIR/attendance.log" ]; then
        cp "$REP_DIR/attendance.log" "$ARCH_ATT/attendance_${TIMESTAMP}.log"
        echo "Archived: $ARCH_ATT/attendance_${TIMESTAMP}.log"
    else
        echo "Notice: No active 'attendance.log' telemetry generated yet."
    fi

    # Archive the absence log (just print a notice if it is missing)
    if [ -f "$REP_DIR/absent.log" ]; then
        cp "$REP_DIR/absent.log" "$ARCH_ABS/absent_${TIMESTAMP}.log"
        echo "Archived: $ARCH_ABS/absent_${TIMESTAMP}.log"
    else
        echo "Notice: No active 'absent.log' context captured during this session."
    fi
}


# 4. FEATURE 1: APPLICATION DEPLOYMENT

deploy_application() {
    # Phase A: Check that the required tools are installed
    echo "Validating binary compilation profiles..."
    if ! command -v python3 &> /dev/null; then
        echo "Error: python3 runtime is missing or not bound to your environment PATH." >&2
        exit 1
    fi
    if ! command -v zip &> /dev/null; then
        echo "Error: zip compilation package engine is missing." >&2
        exit 1
    fi
    echo "Binary check passed successfully ($(python3 --version))."

    # Phase B: Get the project name and protect any existing directory
    read -p "Enter unique target suffix identity for this deployment: " DIR_INPUT
    if [ -z "$DIR_INPUT" ]; then
        echo "Error: Identity suffix cannot be blank." >&2
        exit 1
    fi
    PROJECT_DIR="attendance_tracker_${DIR_INPUT}"

    if [ -d "$PROJECT_DIR" ]; then
        read -p "Workspace '$PROJECT_DIR' already exists. Overwrite? (y/N): " OVERWRITE
        if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
            echo "Deployment aborted safely to protect historical data profiles."
            exit 1
        fi
        rm -rf "$PROJECT_DIR"
    fi

    # Phase C: Turn the interrupt trap on (Ctrl+C / Ctrl+Z)
    trap cleanup_on_interrupt SIGINT SIGTSTP

    echo "Provisioning structural directory map nodes..."
    mkdir -p "$PROJECT_DIR/Helpers"
    mkdir -p "$PROJECT_DIR/reports"
    mkdir -p "$PROJECT_DIR/archives/attendance"
    mkdir -p "$PROJECT_DIR/archives/absent"

    # Deliberate pause so the interrupt trap can be tested safely
    echo "Syncing structural files (Press Ctrl+C / Ctrl+Z) if want to continue later on)..."
    sleep 3

    cp "$TEMPLATES_DIR/attendance_checker.py" "$PROJECT_DIR/"
    cp "$TEMPLATES_DIR/config.json" "$PROJECT_DIR/Helpers/"

    # Phase D: Choose how the student roster is built
    echo "Select Roster Generation Strategy:"
    echo "  A) Import historical baseline records slice from templates"
    echo "  B) Build pristine dataset with fresh 0 historical counts"
    read -p "Selection (A or B): " ROSTER_OPT

    if [[ "$ROSTER_OPT" =~ ^[Aa]$ ]]; then
        read -p "How many records would you like to parse from baseline template (1-10)? " ROSTER_COUNT
        if ! [[ "$ROSTER_COUNT" =~ ^[0-9]+$ ]] || [ "$ROSTER_COUNT" -lt 1 ] || [ "$ROSTER_COUNT" -gt 10 ]; then
            echo "[-] Input invalid. Defaulting baseline parsing matrix to 5 rows."
            ROSTER_COUNT=5
        fi
        head -n 1 "$TEMPLATES_DIR/assets.csv" > "$PROJECT_DIR/Helpers/assets.csv"
        tail -n +2 "$TEMPLATES_DIR/assets.csv" | head -n "$ROSTER_COUNT" >> "$PROJECT_DIR/Helpers/assets.csv"
        
        # Keep total_sessions in step with the roster history (4 past sessions + today = 5)
        sed -i 's/"total_sessions": [0-9]*/"total_sessions": 5/g' "$PROJECT_DIR/Helpers/config.json"

    elif [[ "$ROSTER_OPT" =~ ^[Bb]$ ]]; then
        read -p "How many student rows do you want to generate dynamically? " GEN_COUNT
        if ! [[ "$GEN_COUNT" =~ ^[0-9]+$ ]] || [ "$GEN_COUNT" -lt 1 ]; then
            echo "Input invalid. Defaulting generation schema to 3 students."
            GEN_COUNT=3
        fi
        
        # Sample names and emails used to generate the students
        LOCAL_NAMES=("ishimwe arstide" "sugira thierry" "shema yves" "pitty trap" "akeza ynes")
        LOCAL_EMAILS=("ishimwe20@example.com" "sugira1@example.com" "pitty@example.com" "divine@example.com" "ynes@example.com")
        
        echo "Email,Names,Attendance Count,Absence Count" > "$PROJECT_DIR/Helpers/assets.csv"
        for ((i=0; i<GEN_COUNT; i++)); do
            idx=$((i % 5))
            if [ $i -ge 5 ]; then
                echo "${i}_${LOCAL_EMAILS[$idx]},${LOCAL_NAMES[$idx]} $i,0,0" >> "$PROJECT_DIR/Helpers/assets.csv"
            else
                echo "${LOCAL_EMAILS[$idx]},${LOCAL_NAMES[$idx]},0,0" >> "$PROJECT_DIR/Helpers/assets.csv"
            fi
        done
        # A fresh roster has no history, so today is the first session (= 1)
        sed -i 's/"total_sessions": [0-9]*/"total_sessions": 1/g' "$PROJECT_DIR/Helpers/config.json"
    else
        echo "It actually raises my pressure!! My heart was beating 180Unidentified operational sequence path. Cleaning tree and closing setup."
        rm -rf "$PROJECT_DIR"
        exit 1
    fi

    # Phase E: Set file permissions
    chmod +x "$PROJECT_DIR/attendance_checker.py"
    chmod 600 "$PROJECT_DIR/Helpers/config.json"
    echo "[+] Access controls and locks applied successfully:"
    ls -l "$PROJECT_DIR/attendance_checker.py"
    ls -l "$PROJECT_DIR/Helpers/config.json"

    # Phase F: Optionally change the warning and failure thresholds
    read -p "Do you want to override baseline grading evaluation metrics? (y/N): " CHANGE_THRESH
    if [[ "$CHANGE_THRESH" =~ ^[Yy]$ ]]; then
        read -p "Set custom Warning Boundary Limit Value (0-100): " WARN_VAL
        read -p "Set custom Failure Boundary Limit Value (0-100): " FAIL_VAL
        if [[ "$WARN_VAL" =~ ^[0-9]+$ ]] && [[ "$FAIL_VAL" =~ ^[0-9]+$ ]]; then
            sed -i "s/\"warning\": [0-9]*/\"warning\": $WARN_VAL/g" "$PROJECT_DIR/Helpers/config.json"
            sed -i "s/\"failure\": [0-9]*/\"failure\": $FAIL_VAL/g" "$PROJECT_DIR/Helpers/config.json"
            echo "Operational boundary metrics locked into config.json."
        else
            echo "Non-numeric threshold input captured. Retaining strict platform defaults."
        fi
    fi

    # Turn the interrupt trap off before the app takes over terminal input
    trap - SIGINT SIGTSTP
    echo "System workspace pipeline online. Dropping directly into structural check validation loop..."
    
    # Launch the app straight away to verify the deployment
    run_application "$PROJECT_DIR"
}

# 5. MAIN MENU LOOP
 while true; do

 echo -e "\n=========================================================================="
    echo "              AUTOMATED STUDENT ATTENDANCE AGENT                 "
    echo "=========================================================================="
    echo "1) Deploy and Verify Application Instance"
    echo "2) Run Pre-existing Deployment Environment"
    echo "3) Archive Operation Runtime Output Logs"
    echo "4) Exit Automation Script Execution Context"
    echo "=========================================================================="
    read -p "Select options from system operation framework (1-4): " ENGINE_CHOICE

    case $ENGINE_CHOICE in
        1) deploy_application ;;
        2) run_application ;;
        3) archive_logs ;;
        4) echo "[+] Exiting Agent interface. Context returned safely to user console."; exit 0 ;;
        *) echo "[-] Choice not mapped to system operations framework configuration options." ;;
    esac 
done 
