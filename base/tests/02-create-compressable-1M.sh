#!/bin/bash
echo -e "[$(date +%s.%N)] Test 02: Creating an 1M compressable file."
exec dd if="$COMPRESSABLE_FILE" of="02-compressable-$1.testfile" bs=8K count=128 skip=$(shuf -i0-$(($(stat -c%s "$COMPRESSABLE_FILE") - 1024 * 1024)) -n1) status=none
