FROM mongo:latest

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN pushd /usr/local/bin \
  && curl -O "http://stedolan.github.io/jq/download/linux64/jq" \
  && chmod +x jq \
  && popd \
  && mv /entrypoint.sh /mongo_entry.sh

COPY ./entrypoint.sh ./health.sh ./service.json.tmpl /
