#!/bin/bash
echo -e "[$(date +%s.%N)] Test 07: Append 16 bytes to an existing 16M file."
exec dd if=/dev/urandom bs=16 count=1 status=none >> "04-uncompressable-$1.testfile"
