#!/bin/bash
echo -e "[$(date +%s.%N)] Test 03: Creating an 1M uncompressable file."
exec dd if=/dev/urandom of="03-uncompressable-$1.testfile" bs=8K count=128 status=none
