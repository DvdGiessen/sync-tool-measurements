#!/bin/bash
echo -e "[$(date +%s.%N)] Test 04: Creating an duplicate of existing 1M file."
exec cp "03-uncompressable-$1.testfile" "04-duplicate-$1.testfile"
