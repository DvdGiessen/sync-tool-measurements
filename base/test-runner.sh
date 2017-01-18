#!/bin/bash
if [ -z "$BASH" ] ; then
    echo "This script must be run with bash" >&2
    exit 1
fi
set -eu

# Usage / help text
print_usage() {
    echo "Usage: $0 [-v] PEERCOUNT"
    echo ""
    echo "Sets up a test runner into the current Docker container."
    echo ""
    echo "Options:"
    echo "    -?             Print this message."
    echo "    -v             Enable verbose output."
    echo "    PEERCOUNT      Number of peers to sync up with."
    echo ""
    exit 1
}

# Define argument variables
PEERCOUNT=-1
VERBOSE=0

# Check for arguments
if [[ $# -lt 1 ]] ; then
    print_usage
fi
I=0
while [[ "$#" -ge 1 ]] ; do
    case "$1" in
        "-?"|-h|--help)
            print_usage
        ;;
        -v|--verbose)
            VERBOSE=1
        ;;
        *)
            case "$I" in
                0)
                    printf -v PEERCOUNT '%d' "$1"
                ;;
                *)
                    echo "Unknown parameter \"$1\"" >&2
                    exit 1
                ;;
            esac
            I=$((I+1))
        ;;
    esac
    shift
done

# Check workdir
if [[ -z "$WORKDIR" ]] || [[ ! -d "$WORKDIR" ]] || [[ "$(readlink -f "$WORKDIR")" == "/" ]]; then
    echo -e "[$(date +%s.%N)] \e[91mInvalid WORKDIR environment variable.\e[0m" >&2
    exit 1
fi
rm -rf "$WORKDIR"/*

# Check data volume
if [[ -z "$DATAVOLUME" ]] || [[ ! -d "$DATAVOLUME" ]] || [[ "$(readlink -f "$DATAVOLUME")" == "/" ]]; then
    echo -e "[$(date +%s.%N)] \e[91mInvalid DATAVOLUME environment variable.\e[0m" >&2
    exit 1
fi
rm -rf "$DATAVOLUME"/*

# Set up verbose file descriptor
if [[ $VERBOSE ]] ; then
    exec 3> >(sed --unbuffered -r "s/.*/\x1B\[96m&\x1B\[0m/g" >&2)
else
    exec 3>/dev/null
fi

# Setup the sync tool
echo "[$(date +%s.%N)] Executing sync tool setup ..." >&2
if ! /synctool-setup.sh >&2 ; then
    echo -e "[$(date +%s.%N)] \e[91mSync tool setup failed.\e[0m" >&2
    exit 1
fi

# Set up peers
if [[ $PEERCOUNT -gt 0 ]] ; then
    echo "[$(date +%s.%N)] Setting up $PEERCOUNT peers ..." >&2

    # Wait for peers to start reporting state
    for (( I=1 ; I <= $PEERCOUNT; I++)) ; do
        while [[ ! -f "$DATAVOLUME/$I.state" ]] ; do
            inotifywait -qqt 2 -e create -e moved_to "$DATAVOLUME" || true
        done
        if [[ $VERBOSE ]] ; then
            echo "[$(date +%s.%N)] Peer $I state report found." >&2
        fi
    done
else
    if [[ $PEERCOUNT -lt 0 ]] ; then
        echo -e "[$(date +%s.%N)] \e[91mInvalid peer count argument.\e[0m" >&2
        exit 1
    else
        echo "[$(date +%s.%N)] No peers configured, running in stand-alone mode" >&2
    fi
fi

# Reset current directory
cd /

# Logging directory
LOGDIR="$DATAVOLUME/logs"
mkdir -p "$LOGDIR"

# Generate random seed which may be used by tests
SEED=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 16 | head -n 1)
if [[ $VERBOSE ]] ; then
    echo "[$(date +%s.%N)] Random seed: $SEED" >&2
fi

# Keep track of previous state to detect no-ops
PREVIOUSSTATE='none'

# Loop over all tests
# Start and stop scripts are run like tests so we capture data for them
for TESTSCRIPT in /synctool-start.sh /tests/*.sh /synctool-stop.sh ; do
    LOGFILE="$LOGDIR/$(basename "$TESTSCRIPT" .sh)"
    # Base name for logfiles

    # Start inotifywait and tcpdump to monitor disk and network activity
    echo "[$(date +%s.%N)] Setting up monitoring ..." >&2
    inotifywait -mr "$WORKDIR" > >( while IFS= read -r line ; do echo "$(date +%s.%N) $line" ; done > "$LOGFILE.inotifywaitlog" ) 2>&1 &
    INOTIFYWAIT_PID=$!
    tcpdump -i any -s0 -w "$LOGFILE.tcpdumpdata" > "$LOGFILE.tcpdumplog" 2>&1 &
    TCPDUMP_PID=$!

    # Start the test
    echo "[$(date +%s.%N)] Running $TESTSCRIPT ..." >&2
    TESTTIME=$(date +%s.%N)
    cd "$WORKDIR"
    if ! "$TESTSCRIPT" "$SEED" >&2 ; then
        echo -e "[$(date +%s.%N)] \e[91mRunning $TESTSCRIPT failed!\e[0m" >&2
    fi
    sync
    cd /

    # Only wait for peers if there are peers
    if [[ $PEERCOUNT -gt 0 ]] ; then
        # Create a snapshot of the state of the directory
        STATE=$(find "$WORKDIR" \( ! -regex '.*/\..*' \) -type f -exec cksum {} \; | sort)
        if [[ $VERBOSE ]] ; then
            echo -e "[$(date +%s.%N)] Current state:\n$STATE" >&3
        fi
        
        # Check for no-ops
        if [[ "$STATE" == "$PREVIOUSSTATE" ]] && [[ "$TESTSCRIPT" != "/synctool-stop.sh" ]] ; then
            echo -e "[$(date +%s.%N)] \e[91mThe state was unaltered after running $TESTSCRIPT!\e[0m" >&2
        fi
        PREVIOUSSTATE="$STATE"

        # Wait for all peers report an identical state
        for (( I=1 ; I <= $PEERCOUNT; I++)) ; do
            while [[ "$(flock --shared  --timeout 1 "$DATAVOLUME/$I.lock" -c "cat \"$DATAVOLUME/$I.state\"")" != "$STATE" ]] ; do
                if [[ $VERBOSE ]] ; then
                    echo "[$(date +%s.%N)] Peer $I reported (unequal) state:" >&2
                    flock --shared  --timeout 1 "$DATAVOLUME/$I.lock" -c "cat \"$DATAVOLUME/$I.state\"" >&3
                fi
                inotifywait -qqt 2 -e modify "$DATAVOLUME/$I.state" || true
            done
            if [[ $VERBOSE ]] ; then
                echo "[$(date +%s.%N)] Peer $I reported identical state." >&2
            fi
        done
        echo -e "[$(date +%s.%N)] All $PEERCOUNT peers reported an identical state after ~$(echo $(date +%s.%N) - $TESTTIME | bc) seconds" >&2
    fi

    # Sleep to catch any remaining test activity
    sleep 10

    # Stop the monitoring tasks
    echo "[$(date +%s.%N)] Stopping monitoring ..." >&2
    kill -s TERM $INOTIFYWAIT_PID
    wait $INOTIFYWAIT_PID 2>/dev/null || true
    kill -s TERM $TCPDUMP_PID
    wait $TCPDUMP_PID 2>/dev/null || true
done

# Indicate to peers we're done
if [[ $PEERCOUNT -gt 0 ]] ; then
    echo "[$(date +%s.%N)] Stopping $PEERCOUNT peers ..." >&2
    touch "$DATAVOLUME/done"

    # Wait for peers to shut down
    for (( I=1 ; I <= $PEERCOUNT; I++)) ; do
        while [[ -f "$DATAVOLUME/$I.state" ]] ; do
            inotifywait -qqt 2 -e delete -e moved_from "$DATAVOLUME" || true
        done
    done
fi

# Output the logfiles as a tarball
echo "[$(date +%s.%N)] Outputting logfiles as tarball to standard output ..." >&2
cd $LOGDIR
tar cf - $(find . -mindepth 1 -maxdepth 1 -exec basename {} \;)
exit 0
