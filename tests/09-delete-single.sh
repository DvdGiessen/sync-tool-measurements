#!/bin/bash
echo -e "[$(date +%s.%N)] Test 09: Deleting a single file."
exec rm "01-empty-$1.testfile"
