#!/bin/bash
set -e
cd /

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

# Setup the sync tool
echo "[$(date +%s.%N)] Executing sync tool setup ..." >&2
if ! /synctool-setup.sh >&2 ; then
    echo -e "[$(date +%s.%N)] \e[91mSync tool setup failed.\e[0m" >&2
    exit 1
fi

# Set up peers
printf -v PEERCOUNT '%d' "$1"
if [[ $PEERCOUNT -gt 0 ]] ; then
    echo "[$(date +%s.%N)] Setting up $PEERCOUNT peers ..." >&2

    # Wait for peers to start reporting state
    for (( I=1 ; I <= $PEERCOUNT; I++)) ; do
        while [[ ! -f "$DATAVOLUME/$I.state" ]] ; do
            inotifywait -qqt 2 -e create -e moved_to "$DATAVOLUME" || true
        done
    done
else
    echo "[$(date +%s.%N)] No peers configured, running in stand-alone mode" >&2
fi

# Logging directory
LOGDIR="$DATAVOLUME/logs"
mkdir -p "$LOGDIR"

# Generate random seed which may be used by tests
SEED=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 16 | head -n 1)

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
        
        # Check for no-ops
        if [[ "$STATE" == "$PREVIOUSSTATE" ]] && [[ "$TESTSCRIPT" != "/synctool-stop.sh" ]] ; then
            echo -e "[$(date +%s.%N)] \e[91mThe state was unaltered after running $TESTSCRIPT!\e[0m" >&2
        fi
        PREVIOUSSTATE="$STATE"

        # Wait for all peers report an identical state
        for (( I=1 ; I <= $PEERCOUNT; I++)) ; do
            while [[ "$(cat "$DATAVOLUME/$I.state")" != "$STATE" ]] ; do
                inotifywait -qqt 2 -e modify "$DATAVOLUME/$I.state" || true
            done
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
