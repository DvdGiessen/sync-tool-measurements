#!/bin/bash
set -e

# Check workdir
if [[ -z "$WORKDIR" ]] || [[ ! -d "$WORKDIR" ]]; then
    echo -e "[$(date +%s.%N)] \e[91mInvalid WORKDIR environment variable.\e[0m" >&2
    exit 1
fi

# Setup the sync tool
echo "[$(date +%s.%N)] Executing sync tool setup ..." >&2
if ! /synctool-setup.sh ; then
    echo -e "[$(date +%s.%N)] \e[91mSync tool setup failed.\e[0m" >&2
    exit 1
fi

# Start inotifywait and tcpdump to monitor disk and network activity
echo "[$(date +%s.%N)] Setting up monitoring ..." >&2
LOGDIR=$(mktemp -d)

inotifywait -mr $(readlink -f $WORKDIR) | while IFS= read -r line ; do echo "$(date +%s.%N) $line" ; done > $LOGDIR/inotifywait.log 2>&1 &
INOTIFYWAIT_PID=$!
tcpdump -i any -s0 -w $LOGDIR/tcpdump.dat > $LOGDIR/tcpdump.log 2>&1 &
TCPDUMP_PID=$!

# Start the sync tool
echo "[$(date +%s.%N)] Starting sync tool ..." >&2
if ! /synctool-start.sh ; then
    echo -e "[$(date +%s.%N)] \e[91mRunning sync tool failed.\e[0m" >&2
else
    echo -e "  \e[93m-  Press ENTER to quit  -\e[0m  " >&2
    read
    echo "[$(date +%s.%N)] Stopping sync tool ..." >&2
    /synctool-stop.sh
fi

# Stop the monitoring tasks
echo "[$(date +%s.%N)] Stopping monitoring ..." >&2
kill -s TERM $INOTIFYWAIT_PID
kill -s TERM $TCPDUMP_PID

# Output the logfiles as a tarball
echo "[$(date +%s.%N)] Outputting logfiles to standard output ..." >&2
cd $LOGDIR
tar cf - $(find . -mindepth 1 -maxdepth 1 -exec basename {} \;)
exit 0
