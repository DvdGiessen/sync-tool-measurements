#!/bin/bash
set -e

# Check workdir
if [[ -z "$WORKDIR" ]] || [[ ! -d "$WORKDIR" ]]; then
    echo -e "[$(date +%s.%N)] \e[91mInvalid WORKDIR environment variable.\e[0m" >&2
    exit 1
fi

# Setup the sync tool
echo "[$(date +%s.%N)] Executing sync tool setup ..." >&2
if ! /synctool-setup.sh >&2 ; then
    echo -e "[$(date +%s.%N)] \e[91mSync tool setup failed.\e[0m" >&2
    exit 1
fi

# Set up peers
PEERCOUNT=$(printf -v int '%d\n' "$1" 2>/dev/null)
if [ $PEERCOUNT -gt 0 ] ; then
    echo "[$(date +%s.%N)] Setting up $PEERCOUNT peers ..." >&2

    # Wait for peers to confirm setup
    # TODO
else
    echo "[$(date +%s.%N)] No peers configured, running in stand-alone mode" >&2
fi

# Logging location
LOGDIR=$(mktemp -d)

# Loop over all tests
# Start and stop scripts are run like tests so we capture data for them
for TESTSCRIPT in /synctool-start.sh /tests/*.sh /synctool-stop.sh ; do
    # Base name for logfiles
    LOGFILE="$LOGDIR/$(basename \"$TESTSCRIPT\")"

    # Resolve workdir (may be symlinked)
    WORKREALDIR=$(readlink -f "$WORKDIR")

    if [[ -z "$WORKDIR" ]] || [[ ! -d "$WORKDIR" ]]; then
        echo -e "[$(date +%s.%N)] \e[91mWorking directory was invalidated.\e[0m" >&2
        exit 1
    fi

    # Start inotifywait and tcpdump to monitor disk and network activity
    echo "[$(date +%s.%N)] Setting up monitoring ..." >&2
    inotifywait -mr "$WORKREALDIR" > >( while IFS= read -r line ; do echo "$(date +%s.%N) $line" ; done > "$LOGFILE.inotifywaitlog" ) 2>&1 &
    INOTIFYWAIT_PID=$!
    tcpdump -i any -s0 -w "$LOGFILE.tcpdumpdata" > "$LOGFILE.tcpdumplog" 2>&1 &
    TCPDUMP_PID=$!

    # Start the test
    echo "[$(date +%s.%N)] Running $TESTSCRIPT ..." >&2
    cd "$WORKREALDIR"
    if ! "$TESTSCRIPT" >&2 ; then
        echo -e "[$(date +%s.%N)] \e[91mRunning $TESTSCRIPT failed!\e[0m" >&2
    fi
    cd /

    # Create a snapshot of the directory
    # TODO

    # Wait for all peers report an identical snapshot within a reasonable timeframe
    # If not in sync within this timeout, display an error message
    # TODO

    # Sleep to catch any remaining test activity
    sleep 10

    # Stop the monitoring tasks
    echo "[$(date +%s.%N)] Stopping monitoring ..." >&2
    kill -s TERM $INOTIFYWAIT_PID
    wait $INOTIFYWAIT_PID 2>/dev/null || true
    kill -s TERM $TCPDUMP_PID
    wait $TCPDUMP_PID 2>/dev/null || true
done

# Output the logfiles as a tarball
echo "[$(date +%s.%N)] Outputting logfiles as tarball to standard output ..." >&2
cd $LOGDIR
tar cf - $(find . -mindepth 1 -maxdepth 1 -exec basename {} \;)
exit 0
