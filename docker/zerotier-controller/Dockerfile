FROM ubuntu:focal

ENV DEBIAN_FRONTEND noninteractive

RUN apt update -y && \
	apt upgrade -qy && \
	apt install -qy --no-install-recommends wget curl gnupg ca-certificates xz-utils jq python3-pip && \
	pip3 install libzt requests tabulate && \
	wget -q https://install.zerotier.com/ -O /tmp/install-zerotier.sh && \
	bash /tmp/install-zerotier.sh && \
	find /var/lib/zerotier-one/ -type f -delete

CMD ["/usr/sbin/zerotier-one"]
