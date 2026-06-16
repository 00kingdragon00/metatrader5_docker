FROM kasmweb/core-ubuntu-noble:1.16.1 AS base
USER root

ENV HOME /home/kasm-default-profile
ENV STARTUPDIR /dockerstartup
ENV INST_SCRIPTS $STARTUPDIR/install
ENV WINEPREFIX="/root/.wine"

WORKDIR $HOME

RUN apt-get update && \
    apt-get upgrade -y

RUN apt-get install -y bc dos2unix

RUN dpkg --add-architecture i386
RUN mkdir -pm755 /etc/apt/keyrings

RUN wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
    && wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources

RUN apt-get update && \
    apt-get upgrade -y

RUN apt install --install-recommends -y \
    winehq-stable=10.0.0.0~noble-1 \
    wine-stable=10.0.0.0~noble-1 \
    wine-stable-amd64=10.0.0.0~noble-1 \
    wine-stable-i386=10.0.0.0~noble-1 \
    && apt-get clean

RUN chown 1000:0 $HOME
RUN $STARTUPDIR/set_user_permission.sh $HOME

ENV HOME /home/kasm-user
WORKDIR $HOME

RUN mkdir -p $HOME && chown -R 1000:0 $HOME

COPY ./scripts /scripts
RUN dos2unix /scripts/*.sh && chmod +x /scripts/*.sh

RUN printf '#!/usr/bin/env bash\nexec /scripts/01-start.sh\n' > $STARTUPDIR/custom_startup.sh \
    && chmod +x $STARTUPDIR/custom_startup.sh
