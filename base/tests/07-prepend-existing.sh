#!/bin/bash
echo -e "[$(date +%s.%N)] Test 07: Prepend 16 bytes to an existing 1M file."
TEMPFILE=$(mktemp)
exec dd if=/dev/urandom bs=16 count=1 status=none | cat - "03-uncompressable-$1.testfile" > "$TEMPFILE" && dd if="$TEMPFILE" of="03-uncompressable-$1.testfile" bs=8K status=none
