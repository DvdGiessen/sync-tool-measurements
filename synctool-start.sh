#!/bin/bash
echo -e "[$(date +%s.%N)] \e[91mBase image cannot be run directly, please set up a child image containing a sync tool.\e[0m"
exit 1
