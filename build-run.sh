#!/bin/bash
set -e

# Build all images
echo "[$(date +%s.%N)] Building Docker images ..." >&2
docker build -t "utw-cn:base" .
docker build -t "utw-cn:dropbox" dropbox

# Determine number of peers
printf -v PEERCOUNT '%d' "$1"

# Create the test runner container
RUNNER=$(docker create -i --tmpfs "/workdir" "utw-cn:dropbox" /test-runner.sh $PEERCOUNT)

# Set up peers
if [[ $PEERCOUNT -gt 0 ]] ; then
    echo "[$(date +%s.%N)] Creating $PEERCOUNT peers ..." >&2

    # Create and run peers
    PEERS=()
    for (( I=1 ; I <= $PEERCOUNT; I++)) ; do
        PEERS[$(($I - 1))]=$(docker create -ti --tmpfs /workdir --volumes-from "$RUNNER" "utw-cn:dropbox" /test-peer.sh $I)
        echo -e "  \e[93m-  Press Ctrl-P Ctrl-Q after completing Dropbox setup and pressing ENTER  -\e[0m  " >&2
        if ! docker start -ai "${PEERS[$(($I - 1))]}" ; then
            echo -e "[$(date +%s.%N)] \e[91mStart of peer $I failed!\e[0m" >&2
            echo "[$(date +%s.%N)] Removing containers ..." >&2
            for (( J=1 ; J <= $I; J++)) ; do
                docker rm -f "${PEERS[$(($J - 1))]}" >/dev/null
            done
            docker rm -f "$RUNNER" >/dev/null
            exit 1
        fi
    done
fi

# Start the test runner
echo "[$(date +%s.%N)] Executing test runner ..." >&2
if ! docker start -ai "$RUNNER" > results.tar ; then
    echo -e "[$(date +%s.%N)] \e[91mExecuting test runner failed!\e[0m" >&2
fi

# Destroy all containers
echo "[$(date +%s.%N)] Removing containers ..." >&2
if [[ $PEERCOUNT -gt 0 ]] ; then
    for (( I=1 ; I <= $PEERCOUNT; I++)) ; do
        docker rm -f "${PEERS[$(($I - 1))]}" >/dev/null
    done
fi
docker rm -f "$RUNNER" >/dev/null
