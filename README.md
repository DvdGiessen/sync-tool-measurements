# File synchronization application measurement

This repository contains a set of bash scripts and Dockerfiles which can be
used for measuring the performance and data efficiency of file
synchronization software. I wrote it to help me more efficiently collect
measurements for the 'Cloud Networking' course project at the University of
Twente.

## Overview
We test the sync applications by setting up multiple Docker containers with the
client applications, all set up connected with a single synchronized directory.
The containers record all disk access and network activity for analysis
purposes. One client then runs a suite of tests, and wait for all peer clients
to have their directories synced, which is checked by comparing checksums of
the entire directories.

The tests create, modify and delete files in the synchronized directory. Each
test is designed to test a specific aspect which a synchronization tool might
handle differently. Data is recorded per test.

This repository contains a base container image which has all the test scripts
but no sync application implemented. Sync applications are implemented by
building upon this base image.

The `build-run.sh` script in the repository root is a simple script for setting
up a test run for a specific client software and number of peers. It saves all
its output in a compressed tarball in the working directory. `collect-stats.sh`
is a (not very efficient) script for extracting some basic data from the result
files and outputting it as CSV. Because proper scientists use Excel for their
analysis, or at least for the fancy result graphs. :)

## Open issues
Dropbox requires linking the client through their website. Solution might be to
automate this by extracting the URL from the console output and using a
headless browser to link the client, but for the time being it just requires
some human interaction.

Currently Docker data volumes are used for communicating between the test
runner and its peers, which isn't exactly ideal since it prevents deployment on
distributed Docker machines for large-scale testing and limits the ability to
measure on non-virtual network infrastructures. Best way forward would be to
implement a proper protocol for communicating with peers and put those on a
separate (virtual) network (as not to show up in and thus impact measurements),
at which point it might be useful to consider switching away from bash as well.

More clients should be implemented. For the (very small) scope of the course I
only implemented Dropbox and Resilio Sync (formerly Bittorrent Sync), however
it should be feasible to implement almost any file sync app which can run under
Linux.

## License and contributing
All code in this repository is made available under the MIT license.

Although I'm not actively developing this code, contributions are welcome, just
open a pull request.
