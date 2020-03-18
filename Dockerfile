FROM nvidia/opencl:latest

LABEL title="Folding@home client with CUDA drivers" \
  maintainer="Carlos Milán Figueredo" \
  version="${VERSION}" \
  url1="https://calnus.com" \
  url2="http://www.hispamsx.org" \
  contrib1="Carlos Mendible - https://github.com/cmendible/folding-at-home" \
  contrib2="amalic - https://hub.docker.com/r/amalic/nvdocker-folding-home" \
  bbs="telnet://bbs.hispamsx.org" \
  twitter="@cmilanf" \
  thanksto="Beatriz Sebastián Peña" \
  usage="docker run -it --rm cmilanf/fahclient --user=<username> --team=<team number> --gpu=<true or false> --smp=<true or false> --power=<light, medium or full>"

ARG DEBIAN_FRONTEND=noninteractive
ARG FAHCLIENT_VERSION=7.5.1
ARG FAHCLIENT_MAJOR_VERSION=7.5
ARG FAHCLIENT_DOWNLOAD_URL=https://download.foldingathome.org/releases/public/release/fahclient/debian-stable-64bit/v${FAHCLIENT_MAJOR_VERSION}/fahclient_${FAHCLIENT_VERSION}_amd64.deb

RUN apt-get update \
    && apt-get -y install --no-install-recommends wget \
    && wget --no-check-certificate -O /tmp/fahclient.deb ${FAHCLIENT_DOWNLOAD_URL} \
    && dpkg --unpack /tmp/fahclient.deb \
    && rm -f /var/lib/dpkg/info/fahclient.postinst \
    && dpkg --configure fahclient \
    && apt-get install -yf \
    && rm -f /tmp/fahclient.deb

ENTRYPOINT ["/usr/bin/FAHClient"]
CMD ["--user=Anonymous", "--team=0", "--gpu=false", "--smp=true", "--power=full"]