#!/bin/bash
echo -e "[$(date +%s.%N)] Test 99: Deleting multiple files."
exec rm "02-compressable.testfile" "03-uncompressable.testfile"
