#!/bin/bash
echo -e "[$(date +%s.%N)] Test 10: Deleting multiple files."
exec rm "02-compressable-$1.testfile" "03-uncompressable-$1.testfile" "04-duplicate-$1.testfile"
