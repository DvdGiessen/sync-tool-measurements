#!/bin/bash
echo -e "[$(date +%s.%N)] Test 05: Creating an duplicate of existing 16M file."
exec cp "04-uncompressable-$1.testfile" "05-duplicate-$1.testfile"
