FROM ubuntu:noble

ARG TARGETARCH
ARG ENGINE=main
ARG VERSION=10.13.1
ARG TEST=deb.vaxtor.com
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install base build dependencies, configure Vaxtor repository and install vaxtorgenesis app
RUN apt-get update && apt-get install -y wget gnupg tini libmariadb3 ca-certificates curl libxml2-utils dbus \
    && wget -q -O - https://nexus.vaxtor.com/repository/keys/keyring.gpg | tee /etc/apt/trusted.gpg.d/vaxtor-keyring.gpg >/dev/null \
    && echo deb [signed-by=/etc/apt/trusted.gpg.d/vaxtor-keyring.gpg] http://deb.vaxtor.com noble main > /etc/apt/sources.list.d/vaxtor-noble.list \
    && apt-get update \
    && apt-get install -y vaxtorgenesis \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Manually download and install the HASP Driver (Dynamic per Architecture)
RUN cd /tmp \
    && wget -L https://nexus.vaxtor.com/repository/sentinel/aksusbd-${VERSION}.tar -O aksusbd.tar \
    && tar xvf aksusbd.tar \
    && cd aksusbd-${VERSION} \
    && mkdir -p /etc/hasplm/templates /etc/hasplm/help /opt/hasp_libs \
    && if [ "$TARGETARCH" = "arm64" ]; then HASP_BIN="hasplmd_arm64"; \
       elif [ "$TARGETARCH" = "arm" ]; then HASP_BIN="hasplmd_armhf"; \
       elif [ "$TARGETARCH" = "amd64" ]; then HASP_BIN="hasplmd_x86_64"; \
       else echo "[ERROR] Unsupported architecture: $TARGETARCH" && exit 1; fi \
    && install -c -m 555 -g root -o root bin/${HASP_BIN} /usr/sbin/hasplmd \
    && install -c -m 644 -g root -o root bin/*.alp /etc/hasplm/templates \
    && tar -xvf bin/help.tar -C /etc/hasplm \
    && chown -R root:root /etc/hasplm/help \
    && chmod -R a=rX /etc/hasplm/help \
    && chmod 555 *.so \
    && cp *.so /opt/hasp_libs/ \
    && cd / \
    && rm -rf /tmp/aksusbd*

# 3. Copy configurations, license management, and execution scripts
COPY hasplm.ini /etc/hasplm/hasplm.ini 
COPY --chmod=755 activate.sh /root/activate.sh
COPY --chmod=755 entrypoint.sh /root/entrypoint.sh
COPY --chmod=755 default-app.sh /root/default-app.sh

EXPOSE 1947/tcp 1947/udp 8444/tcp

# Volume to persist the local license
VOLUME ["/var/hasplm"]

WORKDIR /root

# Use tini as PID 1 for secure process management
ENTRYPOINT ["/usr/bin/tini", "--", "/root/entrypoint.sh"]

# Default command: Execute application logic
CMD ["/root/default-app.sh"]
