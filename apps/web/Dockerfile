FROM node:22-alpine AS build
WORKDIR /app

COPY tsconfig.base.json tsconfig.base.json

COPY packages/core packages/core

COPY apps/web/package.json apps/web/package.json
WORKDIR /app/apps/web
RUN npm install

COPY apps/web .

ARG VITE_API_BASE_URL=""
ARG VITE_API_AUTH_TOKEN=""
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
ENV VITE_API_AUTH_TOKEN=$VITE_API_AUTH_TOKEN

RUN npm run build

FROM nginx:alpine
COPY --from=build /app/apps/web/dist /usr/share/nginx/html
COPY apps/web/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
