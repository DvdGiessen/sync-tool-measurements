# Software versions
FROM ubuntu:16.10

# Install dependencies
RUN apt-get update && apt-get install -y bc curl inotify-tools net-tools tcpdump

# Directory to be synced
ENV WORKDIR /workdir
RUN mkdir -p $WORKDIR && chmod 777 $WORKDIR

# Data volume for communicating with peers
ENV DATAVOLUME /data
RUN mkdir -p $DATAVOLUME && chmod 777 $DATAVOLUME
VOLUME ["/data"]

# Compressable test data
ENV COMPRESSABLE_FILE /shakespeare.txt
COPY ["shakespeare.txt", "/"]
RUN chmod 444 "$COMPRESSABLE_FILE"

# Testing scripts
COPY ["synctool-setup.sh", "/"]
COPY ["synctool-start.sh", "/"]
COPY ["synctool-stop.sh", "/"]
COPY ["test-runner.sh", "/"]
COPY ["test-peer.sh", "/"]
COPY ["tests/*.sh", "/tests/"]
RUN chmod 555 /synctool-setup.sh /synctool-start.sh /synctool-stop.sh /test-runner.sh /test-peer.sh /tests/*.sh

# Execute test script
CMD ["/test-runner.sh"]
