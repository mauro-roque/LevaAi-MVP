# Compila o Flutter Web em uma imagem descartável.
FROM ghcr.io/cirruslabs/flutter:3.29.3 AS flutter-build
WORKDIR /app/frontEnd/leva_ai
COPY frontEnd/leva_ai/pubspec.yaml frontEnd/leva_ai/pubspec.lock ./
RUN flutter pub get
COPY frontEnd/leva_ai ./
RUN flutter build web --release

# Executa somente a API e os arquivos Web gerados.
FROM node:22-bookworm-slim AS runtime
WORKDIR /app/backend
ENV NODE_ENV=production
COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev
COPY backend ./
COPY --from=flutter-build /app/frontEnd/leva_ai/build /app/frontEnd/leva_ai/build
EXPOSE 10000
CMD ["node", "src/server.mjs"]
