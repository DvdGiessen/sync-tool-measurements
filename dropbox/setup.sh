#!/bin/bash
set -e

# Execute deamon for first-time setup
dropboxd &
DROPBOXD_PID=$!

# Wait for setup to complete
echo -e "  \e[93m-  Press ENTER once Dropbox setup is completed  -\e[0m  "
read
kill -s TERM $DROPBOXD_PID
wait $DROPBOXD_PID 2>/dev/null || true

# Check for Dropbox directory existance
if [[ ! -d "~/Dropbox" ]] ; then
    echo -e "[$(date +%s.%N)] \e[91mDropbox direcory not found, presumably setup failed.\e[0m"
    exit 1
fi

# Symlink workdir to Dropbox directory
rm -rf $WORKDIR
ln -s ~/Dropbox $WORKDIR
