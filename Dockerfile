## Build stage for kenon-social-protection-frontend
FROM node:16-bullseye AS build-stage

# Create app directory
RUN mkdir /app
COPY ./ /app
WORKDIR /app
RUN chown node /app -R

# Install serve for static hosting
RUN npm install --global serve

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

# Load config
RUN npm run load-config || true

# Install dependencies
RUN npm install --legacy-peer-deps

# Install missing peer dependencies for MUI & material-table
RUN npm install \
    @material-table/core \
    @material-ui/core \
    @material-ui/icons \
    @material-ui/lab \
    @material-ui/pickers \
    @material-ui/styles \
    @mui/material \
    @mui/lab \
    @mui/icons-material \
    @mui/styles \
    @mui/system \
    @mui/utils \
    @mui/x-date-pickers \
    @emotion/react \
    @emotion/styled \
    @emotion/cache \
    --legacy-peer-deps || true

# Alias material-table
RUN cd node_modules && ln -sf @material-table/core material-table || true

# Build frontend
RUN npm run build

## ---- NGINX Stage ----
FROM nginx:latest

# Copy built app
COPY --from=build-stage /app/build/ /usr/share/nginx/html

# Copy default certs
COPY --from=build-stage /etc/ssl/private/ /etc/nginx/ssl/live/host

# Copy nginx config & entrypoint
COPY ./conf /conf
COPY script/entrypoint.sh /script/entrypoint.sh

# Generate Diffie-Hellman parameters
RUN openssl dhparam -out /etc/nginx/dhparam.pem 2048

# Make entrypoint executable
RUN chmod +x /script/entrypoint.sh

WORKDIR /script

# Environment variables
ENV DATA_UPLOAD_MAX_MEMORY_SIZE=12582912
ENV KENON_HOST="localhost"
ENV PUBLIC_URL="front"
ENV REACT_APP_API_URL="api"
ENV ROOT_MOBILEAPI="rest"
ENV FORCE_RELOAD=""
ENV OPENSEARCH_PROXY_ROOT="opensearch"

# Fix entrypoint to use 'start' by default
RUN sed -i '/^case "\$1" in/a \
  "" ) \
    set -- start ;;' /script/entrypoint.sh

# Entrypoint + default CMD
ENTRYPOINT ["/bin/bash", "/script/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
