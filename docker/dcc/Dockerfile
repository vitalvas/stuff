FROM ubuntu:bionic

ENV DEBIAN_FRONTEND=noninteractive

ARG version=2.3.167

RUN apt update && \
    apt install --no-install-recommends --no-install-suggests -y wget ca-certificates gcc libc-dev libmilter-dev make && \
    cd /usr/src && \
    wget -O dcc.tar.Z https://www.dcc-servers.net/dcc/source/old/dcc-${version}.tar.Z && \
    tar xzvf dcc.tar.Z && \
    cd dcc-${version} && \
    ./configure --homedir=/dcc/conf --bindir=/dcc/bin --libexecdir=/dcc/bin && \
    make install && \
    cd / && \
    rm -rf /usr/src/dcc* && \
    mv /dcc/conf/cgi-bin/ /dcc && \
    mv /dcc/conf/log/ /dcc && \
    sed -i 's/_ENABLE=.*/_ENABLE=on/g' /dcc/conf/dcc_conf && \
    sed -i 's/DCCM_LOG_AT=.*/DCCM_LOG_AT=NEVER/g' /dcc/conf/dcc_conf && \
    sed -i 's/DCCM_REJECT_AT=.*/DCCM_REJECT_AT=MANY/g' /dcc/conf/dcc_conf && \
    sed -i 's/"D?log"/"\/dcc\/log"/g' /dcc/conf/dcc_conf && \
    apt purge -y curl gcc ca-certificates libc-dev make

CMD [ \
    "/dcc/bin/dccifd", \
    "-tREP,20", \
    "-tCMN,NEVER,MANY", \
    "-l/dcc/log", \
    "-w/dcc/conf/whiteclnt", \
    "-U/dcc/conf", \
    "-SHELO", \
    "-Smail_host", \
    "-SSender", \
    "-SList-ID", \
    "-b", \
    "-p *,10045,10.0.0.0/8" \
]
