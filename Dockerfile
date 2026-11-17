# --- Stage 1: Build ---
# Node wird nur zum Bauen gebraucht und landet nicht im finalen Image.
FROM node:24-alpine AS build
WORKDIR /app

# Lockfile zuerst kopieren, damit der npm-ci-Layer nur bei Dependency-Änderungen neu gebaut wird.
COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Vite kompiliert diese Werte fest in das JS-Bundle ein, daher als Build-ARG (nicht als Runtime-ENV).
ARG VITE_API_BASE_URL
ARG VITE_IMGS=items
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
ENV VITE_IMGS=$VITE_IMGS
RUN npm run build

# --- Stage 2: Runtime ---
# Schlankes Laufzeit-Image: nur die fertigen statischen Dateien + nginx, kein Node/node_modules/Quellcode.
FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Von der Pipeline gesetzt (Git-Tag bzw. Commit) und unter /version.json sichtbar.
ARG APP_VERSION=dev
ARG APP_COMMIT=unknown
RUN printf '{"version":"%s","commit":"%s"}\n' "$APP_VERSION" "$APP_COMMIT" > /usr/share/nginx/html/version.json

EXPOSE 80
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1
