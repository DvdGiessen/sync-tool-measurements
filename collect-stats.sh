#!/bin/bash

# Check if tshark is available
if [[ -z "$(which tshark)" ]] || ! tshark -v >/dev/null 2>&1; then
    echo "tshark should be installed and working" >&2
    exit 1
fi

# CSV settings
CSVSEP=';'
CSVQUOTE='"'
DECIMALSEP=','

# Metric functions
METRICS="metric_time metric_size"
metric_time() {
    RESULTFILE=$1
    TESTNAME=$2
    
    # Extract the runner log
    TMPDIR=$(mktemp -d)
    tar xzf "$RESULTFILE" -C "$TMPDIR" "runner.log"
    
    # Look up the estimated time
    grep -m 1 -A 999 "$TESTNAME" "$TMPDIR/runner.log" | grep -m 1 'reported an identical state after' | cut -d' ' -f10 | cut -b2-
    
    # Remove the extracted runner log
    rm -f "$TMPDIR/runner.log"
}
metric_size() {
    RESULTFILE=$1
    TESTNAME=$2
    
    # Extract the PCAP file
    TMPDIR=$(mktemp -d)
    tar xzf "$RESULTFILE" -C "$TMPDIR" "$TESTNAME-tcpdump.pcap"
    
    # Get byte count
    tshark -r "$TMPDIR/$TESTNAME-tcpdump.pcap" -q -z io,stat,0 | grep ' 0.0' | awk '{ print $8 }'
    
    # Remove extracted PCAP file
    rm -f "$TMPDIR/$TESTNAME-tcpdump.pcap"
}

# Make a list of clients
CLIENTS=$(find [^-.]* -mindepth 1 -maxdepth 1 -type f -name Dockerfile -not -path "base/Dockerfile" -printf "$CSVSEP$CSVQUOTE%h$CSVQUOTE")

# Collect data for each test
for TESTSCRIPT in /base/synctool-start.sh ./base/tests/*.sh ./base/synctool-stop.sh ; do
    TESTNAME=$(basename "$TESTSCRIPT" .sh)
    for METRIC in $METRICS ; do
        echo "$CSVQUOTE$TESTNAME: $METRIC$CSVQUOTE$CLIENTS"
        for RESULTFILE in ./results-*.tar.gz ; do
            basename "$RESULTFILE" .tar.gz | awk '{ n = split($0, a, "-"); r = a[2] ; for (i = 3; i < n - 1; i++) r = r "-" a[i]; print r, a[n - 1] }' | while read CLIENT PEERS ; do
                RESULT=$($METRIC "$RESULTFILE" "$TESTNAME" | sed -e "s/^\./0./" -e "s/\./$DECIMALSEP/")
                echo "$PEERS$CLIENTS" | sed -e "s/$CSVQUOTE$CLIENT$CSVQUOTE/$RESULT/" -e 's/[a-zA-Z-]//g'
            done
            break
        done
        echo "$CSVQUOTE$CSVQUOTE$CLIENTS" | sed -e 's/[a-zA-Z-]//g'
        break
    done
    break
done
