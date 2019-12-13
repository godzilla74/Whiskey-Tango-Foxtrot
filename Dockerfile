FROM debian:buster
MAINTAINER Justin Farmer

ENV GO111MODULE=on
ENV GOPATH=/opt/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH
ENV DOMAIN=""

RUN apt-get update && \
  apt-get -y install git build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
  libnss3-dev libssl-dev libreadline-dev libffi-dev wget python3 python3-pip \
  git gcc make libpcap-dev chromium unzip jq parallel && \
  rm -rf /var/lib/apt/lists/* && \
  mkdir -p /opt/tools /opt/scripts /opt/results /opt/wordlists \
  "$GOPATH/src" "$GOPATH/bin" "$GOPATH/pkg" && \
  cd /opt && wget -O go1.13.5.tar.gz https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz && \
  tar -C /usr/local -xzf go1.13.5.tar.gz && \
  rm go1.13.5.tar.gz && \
  go version && \
  go get -v -u github.com/OWASP/Amass/v3/... && \
  go get github.com/ffuf/ffuf && \
  go get github.com/tomnomnom/waybackurls && \
  go get -u github.com/tomnomnom/meg && \
  go get -u github.com/tomnomnom/assetfinder && \
  go get -u github.com/tomnomnom/httprobe && \
  cd /opt/tools && git clone https://github.com/blechschmidt/massdns.git && \
  git clone https://github.com/Abss0x7tbh/bass.git && \
  git clone https://github.com/assetnote/commonspeak2-wordlists.git && \
  git clone https://github.com/robertdavidgraham/masscan && \
  wget -O aquatone1.7.zip https://github.com/michenriksen/aquatone/releases/download/v1.7.0/aquatone_linux_amd64_1.7.0.zip && \
  unzip aquatone1.7.zip -d aq_unzip && cd aq_unzip && mv aquatone /usr/local/bin/aquatone && rm -rf aquatone1.7.zip && \
  rm -rf aq_unzip && \
  cd /opt/tools/massdns && make && \
  ln -s /opt/tools/massdns/bin/massdns /usr/local/bin/massdns && \
  cd /opt/tools/masscan && make -j && \
  ln -s /opt/tools/masscan/bin/masscan /usr/local/bin/masscan

WORKDIR /opt/scripts
COPY . .

RUN chmod +x /opt/scripts/subdomain_enum.sh && \
  mv wordlists/raft-all.txt /opt/wordlists/raft-all.txt && \
  mv wordlists/dicc.txt /opt/wordlists/dicc.txt

VOLUME ["/opt/results"]

ENTRYPOINT ["/opt/scripts/subdomain_enum.sh"]
