#!/bin/bash
RSLSYNC_PID=$(cat /root/.sync/sync.pid)
kill -s TERM $RSLSYNC_PID
wait $RSLSYNC_PID 2>/dev/null || true
