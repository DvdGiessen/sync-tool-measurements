#!/bin/bash
echo -e "[$(date +%s.%N)] Test 02: Creating an 1M compressable file."
exec dd if="$COMPRESSABLE_FILE" of="02-compressable.testfile" bs=1K count=1K skip=$(shuf -i0-$(expr $(stat -c%s "$COMPRESSABLE_FILE") - 1024 \* 1024) -n1) status=none
