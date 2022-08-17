FROM alpine:3.16

RUN apk --no-cache add openssh-client bash jq curl

COPY assets /opt/resource/
