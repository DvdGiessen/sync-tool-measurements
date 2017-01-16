#!/bin/bash
exec dropbox start > >( while IFS= read -r line ; do echo "[$(date +%s.%N)] $line" ; done ) &
