FROM ubuntu:focal

RUN apt update && \
	apt upgrade -y && \
	apt install -y lsb-release wget gnupg && \
	wget -O- https://rspamd.com/apt-stable/gpg.key | apt-key add - && \
	echo "deb [arch=amd64] http://rspamd.com/apt-stable/ $(lsb_release -c -s) main" > /etc/apt/sources.list.d/rspamd.list && \
	apt update && \
	apt --no-install-recommends install -y rspamd && \
	apt clean && apt autoclean && rm -rf /var/lib/apt/lists/*

ADD ./conf/ /etc/rspamd/

CMD ["/usr/bin/rspamd", "-c", "/etc/rspamd/rspamd.conf", "-f", "-u", "_rspamd", "-g", "_rspamd"]

