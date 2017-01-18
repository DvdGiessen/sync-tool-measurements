#!/bin/bash
echo -e "[$(date +%s.%N)] Test 04: Creating an 16M uncompressable file."
exec dd if=/dev/urandom of="04-uncompressable-$1.testfile" bs=8K count=2048 status=none
