#!/bin/bash
set -e
docker build -t "utw-cn:base" .
docker build -t "utw-cn:dropbox" dropbox
docker run -i --rm "utw-cn:dropbox" > results.tar
