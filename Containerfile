FROM scratch
ARG TARGETPLATFORM
ENTRYPOINT ["/usr/bin/telesto"]
COPY $TARGETPLATFORM/telesto /usr/bin/
