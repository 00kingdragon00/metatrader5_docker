FROM ghcr.io/linuxserver/baseimage-kasmvnc:ubuntunoble-e7c3e0c8-ls57  AS base

ENV TITLE=MetaTrader
ENV WINEARCH=win64
ENV WINEPREFIX="/config/.wine"
ENV DISPLAY=:0

RUN mkdir -p /config/.wine && \
    chown -R abc:abc /config/.wine && \
    chmod -R 755 /config/.wine

RUN apt-get update && apt-get upgrade -y

RUN dpkg --add-architecture i386 
    
RUN apt-get install -y \
    dos2unix wget \
    python3-pip python3-pyxdg \
    xvfb x11vnc fluxbox novnc \
    websockify unzip supervisor \
    && pip install --upgrade pip


RUN mkdir -pm755 /etc/apt/keyrings
RUN wget -O - https://dl.winehq.org/wine-builds/winehq.key | sudo gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key -
RUN wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bullseye/winehq-bullseye.sources
    
RUN apt-get update

RUN apt install --install-recommends -y \
    winehq-stable \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
    
FROM base

COPY scripts /scripts
RUN dos2unix /scripts/*.sh && \
    chmod +x /scripts/*.sh

RUN touch /var/log/mt5_setup.log && \
    chown root:root /var/log/mt5_setup.log && \
    chmod 644 /var/log/mt5_setup.log

ENTRYPOINT ["/scripts/01-start.sh"]
