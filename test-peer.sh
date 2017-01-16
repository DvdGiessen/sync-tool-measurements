#!/bin/bash
set -e
cd /

# Check workdir
if [[ -z "$WORKDIR" ]] || [[ ! -d "$WORKDIR" ]] || [[ "$(readlink -f "$WORKDIR")" == "/" ]]; then
    echo -e "[$(date +%s.%N)] \e[91mInvalid WORKDIR environment variable.\e[0m" >&2
    exit 1
fi

# Check data volume
if [[ -z "$DATAVOLUME" ]] || [[ ! -d "$DATAVOLUME" ]] || [[ "$(readlink -f "$DATAVOLUME")" == "/" ]]; then
    echo -e "[$(date +%s.%N)] \e[91mInvalid DATAVOLUME environment variable.\e[0m" >&2
    exit 1
fi
if [[ -f "$DATAVOLUME/done" ]] ; then
    echo -e "[$(date +%s.%N)] \e[91mDirty data volume: done indicator already exists.\e[0m" >&2
    exit 1
fi

# Check peer number
printf -v PEERNUMBER '%d' "$1"
if [[ $PEERNUMBER -le 0 ]] ; then
    echo -e "[$(date +%s.%N)] \e[91mInvalid peer number argument.\e[0m" >&2
    exit 1
fi

# Setup the sync tool
echo "[$(date +%s.%N)] [Peer $PEERNUMBER] Executing sync tool setup ..." >&2
if ! /synctool-setup.sh >&2 ; then
    echo -e "[$(date +%s.%N)] [Peer $PEERNUMBER] \e[91mSync tool setup failed.\e[0m" >&2
    exit 1
fi

# Base name for logfiles
LOGDIR="$DATAVOLUME/logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/peer-$PEERNUMBER"

# Start inotifywait and tcpdump to monitor disk and network activity
echo "[$(date +%s.%N)] [Peer $PEERNUMBER] Setting up monitoring ..." >&2
inotifywait -mr "$WORKDIR" > >( while IFS= read -r line ; do echo "$(date +%s.%N) $line" ; done > "$LOGFILE.inotifywaitlog" ) 2>&1 &
INOTIFYWAIT_PID=$!
tcpdump -i any -s0 -w "$LOGFILE.tcpdumpdata" > "$LOGFILE.tcpdumplog" 2>&1 &
TCPDUMP_PID=$!

echo "[$(date +%s.%N)] [Peer $PEERNUMBER] Starting sync tool ..." >&2
if ! /synctool-start.sh >&2 ; then
    echo -e "[$(date +%s.%N)] [Peer $PEERNUMBER] \e[91mStarting sync tool failed!\e[0m" >&2
    exit 1
fi

# Keep reporting state until done indicator is found
while [[ ! -f "$DATAVOLUME/done" ]] ; do
    STATE=$(find "$WORKDIR" \( ! -regex '.*/\..*' \) -type f -exec cksum {} \; | sort)
    if [[ ! -f "$DATAVOLUME/$PEERNUMBER.state" ]] || [[ "$(cat "$DATAVOLUME/$PEERNUMBER.state")" != "$STATE" ]] ; then
        echo "[$(date +%s.%N)] [Peer $PEERNUMBER] Reporting state change ..." >&2
        echo "$STATE" > "$DATAVOLUME/$PEERNUMBER.state"
    fi
    inotifywait -qqrt 5  -e create -e move -e modify -e delete "$WORKDIR" || true
done

echo "[$(date +%s.%N)] [Peer $PEERNUMBER] Stopping sync tool ..." >&2
if ! /synctool-stop.sh >&2 ; then
    echo -e "[$(date +%s.%N)] [Peer $PEERNUMBER] \e[91mStopping sync tool failed!\e[0m" >&2
    exit 1
fi

# Stop the monitoring tasks
echo "[$(date +%s.%N)] [Peer $PEERNUMBER] Stopping monitoring ..." >&2
kill -s TERM $INOTIFYWAIT_PID
wait $INOTIFYWAIT_PID 2>/dev/null || true
kill -s TERM $TCPDUMP_PID
wait $TCPDUMP_PID 2>/dev/null || true

# Remove state report
rm "$DATAVOLUME/$PEERNUMBER.state"
