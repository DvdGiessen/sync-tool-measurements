#!/bin/bash
exec dropbox stop > >( while IFS= read -r line ; do echo "[$(date +%s.%N)] $line" ; done ) &
