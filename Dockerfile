FROM kasmweb/core-ubuntu-focal:1.16.1 AS base
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
    && wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/focal/winehq-focal.sources

RUN apt-get update && \
    apt-get upgrade -y

RUN apt install --install-recommends -y \
    winehq-stable \
    && apt-get clean

RUN chown 1000:0 $HOME
RUN $STARTUPDIR/set_user_permission.sh $HOME

ENV HOME /home/kasm-user
WORKDIR $HOME

RUN mkdir -p $HOME && chown -R 1000:0 $HOME
