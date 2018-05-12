FROM mhart/alpine-node:6 AS build

# python addition to alpine node
RUN apk add --no-cache --virtual .gyp \
        python \
        make \
        g++

WORKDIR /app

# package.json contains Node-RED NPM module and node dependencies
COPY package.json ./
COPY /keys ./keys

RUN npm install

FROM mhart/alpine-node:6 AS release

# Home directory for Node-RED application source code.
RUN mkdir -p /usr/src/node-red

# User data directory, contains flows, config and nodes.
RUN mkdir /data

WORKDIR /usr/src/node-red
RUN mkdir openLV

# Add node-red user so we aren't running as root.
RUN adduser -h /usr/src/node-red -D -H node-red \
    && chown -R node-red:node-red /data \
    && chown -R node-red:node-red /usr/src/node-red

USER node-red

# openLV source code
COPY index.js .
COPY /openLV ./openLV

# Only copy over the functional pieces to a clean image
COPY --from=build /app .

# User configuration directory volume
VOLUME ["/data"]
EXPOSE 1880

# Environment variable holding file path for flows configuration
ENV FLOWS=flows.json
# USER root
# RUN npm install -g lv-cap
USER node-red
CMD ["node", "index.js"]
