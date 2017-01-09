#!/bin/bash
echo -e "[$(date +%s.%N)] Test 98: Deleting single file."
exec rm "01-empty.testfile"
