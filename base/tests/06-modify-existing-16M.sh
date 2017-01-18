#!/bin/bash
echo -e "[$(date +%s.%N)] Test 06: Changing first 16 bytes bytes of an existing 16M file."
exec dd if=/dev/urandom of="04-uncompressable-$1.testfile" conv=notrunc bs=16 count=1 status=none
