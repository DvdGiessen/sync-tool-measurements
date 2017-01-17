# Software versions
FROM utw-cn:base
ENV DROPBOX_DAEMON_URL https://www.dropbox.com/download?plat=lnx.x86_64
ENV DROPBOX_CLI_URL https://www.dropbox.com/download?dl=packages/dropbox.py

# Dependencies for the Dropbox CLI
RUN apt-get install -y python2.7 python-gpgme

# Download and install the Dropbox daemon
RUN curl -LSs "$DROPBOX_DAEMON_URL" | tar xzf - -C ~ && ln -s ~/.dropbox-dist/dropboxd /usr/local/bin/dropboxd

# Download and install the Dropbox CLI client
RUN curl -LSs "$DROPBOX_CLI_URL" > /usr/local/bin/dropbox && chmod 555 /usr/local/bin/dropbox

# Setup scripts
COPY ["setup.sh", "/synctool-setup.sh"]
COPY ["start.sh", "/synctool-start.sh"]
COPY ["stop.sh", "/synctool-stop.sh"]
RUN chmod 555 /synctool-setup.sh /synctool-start.sh /synctool-stop.sh
