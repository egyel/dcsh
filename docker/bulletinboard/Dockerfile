ARG NODE_VERSION=latest

# builder
FROM node:${NODE_VERSION} as builder

WORKDIR /home
RUN apk --no-cache add git && \
    git clone -b v1 https://github.com/docker-training/node-bulletin-board && \
    # building
    cd node-bulletin-board/bulletin-board-app && \
    npm install

# runner
FROM node:${NODE_VERSION}

LABEL version="1.0"

WORKDIR /usr/src/app
COPY --from=builder /home/node-bulletin-board/bulletin-board-app/ .

CMD [ "npm", "start" ]