#!/bin/bash
if [ -z "$BASH" ] ; then
    echo "This script must be run with bash" >&2
    exit 1
fi
set -eu

# Check for docker
if [[ -z "$(which docker)" ]] || ! docker version >/dev/null 2>&1; then
    echo "Docker should be installed and running" >&2
    exit 1
fi

# Usage / help text
print_usage() {
    echo "Usage: $0 [-v] SYNCTOOL PEERCOUNT"
    echo ""
    echo "Runs measurements for the given file sync tool and number of peers."
    echo ""
    echo "Options:"
    echo "    -?             Print this message."
    echo "    -v             Enable verbose output."
    echo "    SYNCTOOL       Sync tool to run tests for. Can be one of:$(find [^-.]* -mindepth 1 -maxdepth 1 -type f -name Dockerfile -not -path "base/Dockerfile" -printf ' %h' )"
    echo "    PEERCOUNT      Number of peers to run in addition to the main test runner."
    echo "                   A value of 0 will run the tests in stand-alone mode."
    echo ""
    echo "Examples:"
    echo "Run the tests on Dropbox with 1 peer:"
    echo "    $0 dropbox 1"
    echo "Run the tests on Resilio Sync with 5 peers:"
    echo "    $0 resilio-sync 5"
    echo ""
    exit 1
}

# Define argument variables
SYNCTOOL=""
PEERCOUNT=""
VERBOSE=0

# Check for arguments
if [[ $# -lt 2 ]] ; then
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
                    SYNCTOOL="$1"
                ;;
                1)
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

# Check the sync tool
if [[ ! -f "$SYNCTOOL/Dockerfile" ]] ; then
    echo "Cannot find Dockerfile for \"$SYNCTOOL\"" >&2
    exit 1
fi

# Set up verbose parameters
if [[ $VERBOSE -eq 1 ]] ; then
    exec 3> >(sed --unbuffered -r "s/.*/\x1B\[36m&\x1B\[0m/g")
    VERBOSEPARAM="-v"
else
    exec 3>/dev/null
    VERBOSEPARAM=""
fi

# Build all images
echo "[$(date +%s.%N)] Building base Docker image ..."
docker build -t "utw-cn:base" base >&3
echo "[$(date +%s.%N)] Building $SYNCTOOL Docker image ..."
docker build -t "utw-cn:$SYNCTOOL" "$SYNCTOOL" >&3

# Create the test runner container
RUNNER=$(docker create -i --tmpfs "/workdir" "utw-cn:$SYNCTOOL" /test-runner.sh $VERBOSEPARAM $PEERCOUNT)

# Set up peers
if [[ $PEERCOUNT -gt 0 ]] ; then
    echo "[$(date +%s.%N)] Creating $PEERCOUNT peers ..."
    
    # Check if peer setup is interactive
    STARTPARAM=""
    if [[ -f "$SYNCTOOL/interactive-setup" ]] ; then
        STARTPARAM="-ai"
        exec 4>&1
    else
        exec 4>/dev/null
    fi

    # Create and run peers
    PEERS=()
    for (( I=1 ; I <= PEERCOUNT; I++)) ; do
        PEERS[$((I - 1))]=$(docker create -ti --tmpfs /workdir --volumes-from "$RUNNER" "utw-cn:$SYNCTOOL" /test-peer.sh $VERBOSEPARAM $I)
        if [[ -n "$STARTPARAM" ]] ; then
            echo -e "  \e[93m-  Press Ctrl-P Ctrl-Q to detach this peer after completing setup  -\e[0m  "
        fi
        if ! docker start $STARTPARAM "${PEERS[$((I - 1))]}" >&4 ; then
            echo -e "[$(date +%s.%N)] \e[91mStart of peer $I failed!\e[0m" >&2
            echo "[$(date +%s.%N)] Removing containers ..."
            for (( J=1 ; J <= I; J++)) ; do
                docker rm -f "${PEERS[$((J - 1))]}" >/dev/null
            done
            docker rm -f "$RUNNER" >/dev/null
            exit 1
        else
            if [[ $VERBOSE -eq 1 ]] ; then
                docker logs --follow --since 0s "${PEERS[$((I - 1))]}" >&3 &
            fi
        fi
    done
fi

# Start the test runner
echo "[$(date +%s.%N)] Executing test runner ..."
RESULTFILE="results-$SYNCTOOL-$PEERCOUNT-$(date +%s).tar.gz"
if docker start -ai "$RUNNER" | gzip -c9 > "$RESULTFILE" ; then
     echo "[$(date +%s.%N)] Saved test results to \"$RESULTFILE\"."
else
    echo -e "[$(date +%s.%N)] \e[91mExecuting test runner failed!\e[0m" >&2
fi

# Destroy all containers
echo "[$(date +%s.%N)] Removing containers ..."
if [[ $PEERCOUNT -gt 0 ]] ; then
    for (( I=1 ; I <= PEERCOUNT; I++)) ; do
        docker rm -f "${PEERS[$((I - 1))]}" >/dev/null
    done
fi
docker rm -f "$RUNNER" >/dev/null
