# Software versions
FROM ubuntu:16.10

# Install inotify-tools
RUN apt-get update && apt-get install -y curl inotify-tools tcpdump

# Directory to be synced
ENV WORKDIR /workdir
RUN mkdir -p $WORKDIR && chmod 777 $WORKDIR

# Testing scripts
COPY ["synctool-setup.sh", "/synctool-setup.sh"]
COPY ["synctool-start.sh", "/synctool-start.sh"]
COPY ["synctool-stop.sh", "/synctool-stop.sh"]
COPY ["test-runner.sh", "/test-runner.sh"]
RUN chmod 555 /synctool-setup.sh /synctool-start.sh /synctool-stop.sh /test-runner.sh

# Execute test script
CMD ["/test-runner.sh"]
