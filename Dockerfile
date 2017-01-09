# Software versions
FROM ubuntu:16.10

# Install inotify-tools
RUN apt-get update && apt-get install -y curl inotify-tools tcpdump

# Directory to be synced
ENV WORKDIR /workdir
RUN mkdir -p $WORKDIR && chmod 777 $WORKDIR

# Compressable test data
ENV COMPRESSABLE_FILE /shakespeare.txt
COPY ["shakespeare.txt", "/"]
RUN chmod 444 "$COMPRESSABLE_FILE"

# Testing scripts
COPY ["synctool-setup.sh", "/"]
COPY ["synctool-start.sh", "/"]
COPY ["synctool-stop.sh", "/"]
COPY ["test-runner.sh", "/"]
COPY ["tests/*.sh", "/tests/"]
RUN chmod 555 /synctool-setup.sh /synctool-start.sh /synctool-stop.sh /test-runner.sh /tests/*.sh

# Execute test script
CMD ["/test-runner.sh"]
