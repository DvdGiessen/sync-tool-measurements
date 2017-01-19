#!/bin/bash
set -eu

# Peer name
if [[ -z "$1" ]] ; then
    PEERNAME="$1"
else 
    PEERNAME=$(hostname)
fi

# If no secret exists, generate one
if [[ ! -f "$DATAVOLUME/rslsync-secret" ]] ; then
    rslsync --generate-secret > "$DATAVOLUME/rslsync-secret"
fi
SYNCSECRET=$(cat "$DATAVOLUME/rslsync-secret")

# Generate a random port
PORT=$(shuf -i7000-9000 -n1)

# Write known hosts data
IP=$(ifconfig | grep "inet " | head -n1 | awk '{print $2}')
KNOWNHOSTS=""
if [[ -f "$DATAVOLUME/rslsync-hosts" ]] ; then
    KNOWNHOSTS=$(cat "$DATAVOLUME/rslsync-hosts")
    echo -n ", \"$IP:$PORT\"" >> "$DATAVOLUME/rslsync-hosts"
else
    echo -n "\"$IP:$PORT\"" > "$DATAVOLUME/rslsync-hosts"
fi

# Link the logfile
mkdir -p /root/.sync
ln -s "$DATAVOLUME/logs/$PEERNAME.log" /root/.sync/sync.log

# Build the configuration file
cat /rslsync-config-template.json \
    | sed "s/\\\$PEERNAME/$(hostname | sed -e 's/[\/&]/\\&/g')/g" \
    | sed "s/\\\$PORT/$(echo "$PORT" | sed -e 's/[\/&]/\\&/g')/g" \
    | sed "s/\\\$SYNCSECRET/$(echo "$SYNCSECRET" | sed -e 's/[\/&]/\\&/g')/g" \
    | sed "s/\\\$WORKDIR/$(echo "$WORKDIR" | sed -e 's/[\/&]/\\&/g')/g" \
    | sed "s/\\\$KNOWNHOSTS/$(echo "$KNOWNHOSTS" | sed -e 's/[\/&]/\\&/g')/g" \
    > /root/.sync/config.json
