FROM alpine
ADD artifactor /bin/
RUN apk -Uuv add ca-certificates
ENTRYPOINT /bin/artifactor
