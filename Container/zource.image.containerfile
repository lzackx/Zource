FROM ubuntu:20.04

MAINTAINER lZackx lzackx@lzackx.com

USER root

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install mongodb vim curl -y
RUN mkdir -p /data/db

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
RUN /bin/bash -c 'source ~/.bashrc'
RUN . ~/.nvm/nvm.sh && nvm install --lts
RUN mkdir -p ~/work/ZourceServer/

COPY ZourceServer /root/work/ZourceServer/
COPY zource.start.sh /root/work/
RUN chmod a+x /root/work/zource.start.sh

EXPOSE 9687

CMD ~/work/zource.start.sh 1>dev/null 2>&1 &
