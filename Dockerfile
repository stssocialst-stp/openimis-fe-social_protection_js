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


## Instala todas as dependências usando o npm padrão da imagem
RUN npm install --legacy-peer-deps

# Só agora define NODE_ENV=production para o restante do build
ENV NODE_ENV=production


# Build frontend
RUN npm run build

# Provide a minimal index.html so Nginx can serve the app
RUN mkdir -p /app/dist && cat > /app/dist/index.html << 'HTML'
<!doctype html>
<html lang="en">
    <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>kenon-social-protection-frontend</title>
    </head>
    <body>
        <div id="root">This is a build of kenon-social-protection-frontend.</div>
        <script type="module" src="/index.es.js"></script>
    </body>
</html>
HTML

## ---- NGINX Stage ----
FROM nginx:latest

# Copy built app (rollup outputs into `dist/`)
COPY --from=build-stage /app/dist/ /usr/share/nginx/html

# Copy default certs
COPY --from=build-stage /etc/ssl/private/ /etc/nginx/ssl/live/host

COPY script/entrypoint.sh /script/entrypoint.sh

RUN chmod +x /script/entrypoint.sh
WORKDIR /script



ENTRYPOINT ["/bin/bash", "/script/entrypoint.sh"]
