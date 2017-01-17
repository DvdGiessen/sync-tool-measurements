#!/bin/bash
echo -e "[$(date +%s.%N)] Test 01: Creating an empty file."
exec touch "01-empty-$1.testfile"
