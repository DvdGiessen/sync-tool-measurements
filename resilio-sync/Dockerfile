# Software versions
FROM utw-cn:base

# Set up Resilio Sync apt repository
RUN echo 'deb http://linux-packages.resilio.com/resilio-sync/deb resilio-sync non-free' > /etc/apt/sources.list.d/resilio-sync.list && \
    curl -LSs https://linux-packages.resilio.com/resilio-sync/key.asc | apt-key add -

# Install Resilio Sync
RUN apt-get update -o Dir::Etc::sourcelist="sources.list.d/resilio-sync.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" && \
    apt-get install resilio-sync

# Copy config template
COPY ["config.json", "/rslsync-config-template.json"]
RUN chmod 666 /rslsync-config-template.json
EXPOSE 7000-9000

# Setup scripts
COPY ["setup.sh", "/synctool-setup.sh"]
COPY ["start.sh", "/synctool-start.sh"]
COPY ["stop.sh", "/synctool-stop.sh"]
RUN chmod 555 /synctool-setup.sh /synctool-start.sh /synctool-stop.sh
