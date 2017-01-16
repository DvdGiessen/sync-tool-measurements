#!/bin/bash
echo -e "[$(date +%s.%N)] Test 05: Changing first 16 bytes bytes of an existing 1M file."
exec dd if=/dev/urandom of="03-uncompressable-$1.testfile" conv=notrunc bs=16 count=1 status=none
