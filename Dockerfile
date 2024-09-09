FROM alpine:3.10
LABEL authors="IACA Electronique"

WORKDIR /app

COPY scripts  .

RUN chmod +x *.sh && apk update && apk add bash libfdisk jq util-linux e2fsprogs e2fsprogs-extra

ENTRYPOINT ["bash","iaca-image-shrinker.sh"]