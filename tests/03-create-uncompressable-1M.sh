#!/bin/bash
echo -e "[$(date +%s.%N)] Test 03: Creating an 1M uncompressable file."
exec dd if=/dev/urandom of="03-uncompressable.testfile" bs=1K count=1K status=none
