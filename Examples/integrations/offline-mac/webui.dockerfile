FROM node:18-alpine

WORKDIR /app

# Install git for cloning
RUN apk add --no-cache git

# Clone the LiveKit agents playground frontend
RUN git clone --depth 1 https://github.com/bithuman-product/examples.git /tmp/repo && \
    cp -r /tmp/repo/integrations/nextjs-ui/. . && \
    rm -rf /tmp/repo

# Install dependencies
RUN npm cache clean --force && \
    npm install --force

# Set LiveKit connection URL
ARG LIVEKIT_URL
ENV NEXT_PUBLIC_LIVEKIT_URL=$LIVEKIT_URL
ENV LIVEKIT_URL=$LIVEKIT_URL

# Build the application
RUN npm run build

# Set production environment
ENV NODE_ENV=production

# Start the application
CMD ["sh", "-c", "npx next start -p ${PORT:-3000}"] 