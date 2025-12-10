## Build stage for kenon-social-protection-frontend
FROM node:16-bullseye AS build-stage

# Create app directory
RUN mkdir /app
COPY ./ /app
WORKDIR /app
RUN chown node /app -R


# Install serve and rollup for static hosting/build
RUN npm install --global serve rollup

# Install system packages
RUN apt-get update && apt-get install -y nano openssl software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Generate self-signed certificate
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/privkey.pem \
    -out /etc/ssl/private/fullchain.pem \
    -subj "/C=ST/ST=SaoTome/L=SaoTome/O=STSSTP/OU=IT/CN=localhost"

USER node
ARG KENON_CONF_JSON
ENV GENERATE_SOURCEMAP=true
ENV KENON_CONF_JSON=${KENON_CONF_JSON}
ENV NODE_ENV=production

## Instala todas as dependências usando o npm padrão da imagem
RUN npm install --legacy-peer-deps


# Build frontend
RUN npm run build

## ---- NGINX Stage ----
FROM nginx:latest

# Copy built app
COPY --from=build-stage /app/build/ /usr/share/nginx/html

# Copy default certs
COPY --from=build-stage /etc/ssl/private/ /etc/nginx/ssl/live/host

COPY script/entrypoint.sh /script/entrypoint.sh

RUN chmod +x /script/entrypoint.sh
WORKDIR /script



ENTRYPOINT ["/bin/bash", "/script/entrypoint.sh"]
