FROM scratch
ARG TARGETPLATFORM
ENTRYPOINT ["/usr/bin/telesto", "serve"]
COPY $TARGETPLATFORM/telesto /usr/bin/
