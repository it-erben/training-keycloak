FROM alpine:3.22
RUN apk add --no-cache openldap-clients ca-certificates coreutils openssl
COPY bin/save-secret bin/decode-guid /usr/local/bin/
RUN chmod 0755 /usr/local/bin/save-secret /usr/local/bin/decode-guid
WORKDIR /ldif
CMD ["sleep", "infinity"]
