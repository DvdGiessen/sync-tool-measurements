#!/bin/bash
echo -e "[$(date +%s.%N)] Test 08: Trunctate 32 bytes of existing 1M file."
exec truncate -s $(($(stat -c%s "03-uncompressable-$1.testfile") - 32)) "03-uncompressable-$1.testfile"
