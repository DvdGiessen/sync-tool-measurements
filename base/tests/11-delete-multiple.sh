#!/bin/bash
echo -e "[$(date +%s.%N)] Test 11: Deleting multiple files."
exec rm "02-compressable-$1.testfile" "03-uncompressable-$1.testfile" "04-uncompressable-$1.testfile" "05-duplicate-$1.testfile"
