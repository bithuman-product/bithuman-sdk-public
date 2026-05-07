FROM node:18-alpine

WORKDIR /app

RUN apk add --no-cache git

RUN git clone --depth 1 https://github.com/bithuman-product/examples.git /tmp/repo && \
    cp -r /tmp/repo/integrations/nextjs-ui/. . && \
    rm -rf /tmp/repo

RUN npm cache clean --force && \
    npm install --force

RUN npm run build

ENV NODE_ENV=production

CMD ["sh", "-c", "node server.js"]
