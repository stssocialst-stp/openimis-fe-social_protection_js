#!/bin/bash
set -e

# Exibe variáveis de ambiente importantes
printenv | grep -E 'KENON|REACT_APP|PUBLIC_URL|API_URL|FORCE_RELOAD|OPENSEARCH' || true

# Se existir build, serve com nginx
if [ -d "/usr/share/nginx/html" ]; then
    echo "Iniciando Nginx para servir o frontend..."
    exec nginx -g 'daemon off;'
else
    echo "Build não encontrado, iniciando em modo desenvolvimento..."
    cd /app
    exec npm start
fi
