#!/bin/bash
set -e

# This is a convenience file for running all the tests
docker build -t "utw-cn:base" .
docker build -t "utw-cn:dropbox" dropbox
docker run -i --rm "utw-cn:dropbox" > results.tar
