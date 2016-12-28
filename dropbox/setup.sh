#!/bin/bash
set -e

# Execute deamon for first-time setup
dropboxd &
DROPBOXD_PID=$!

# Wait for setup to complete
echo -e "  \e[93m-  Press ENTER once Dropbox setup is completed  -\e[0m  " >&2
read
kill -s TERM $DROPBOXD_PID

# Symlink workdir to Dropbox directory
rm -rf $WORKDIR
ln -s ~/Dropbox $WORKDIR
