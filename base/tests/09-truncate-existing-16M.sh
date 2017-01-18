#!/bin/bash
echo -e "[$(date +%s.%N)] Test 09: Trunctate 32 bytes of existing 16M file."
exec truncate -s $(($(stat -c%s "04-uncompressable-$1.testfile") - 32)) "04-uncompressable-$1.testfile"
