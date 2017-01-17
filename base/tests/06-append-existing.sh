#!/bin/bash
echo -e "[$(date +%s.%N)] Test 06: Append 16 bytes to an existing 1M file."
exec dd if=/dev/urandom bs=16 count=1 status=none >> "03-uncompressable-$1.testfile"
