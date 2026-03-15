FROM node:22-alpine AS build
WORKDIR /app/services/api

COPY services/api/package.json ./package.json
COPY packages/core /app/packages/core
RUN npm install

COPY tsconfig.base.json /app/tsconfig.base.json
COPY services/api ./
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app/services/api
ENV NODE_ENV=production
ENV PORT=8787

COPY services/api/package.json ./package.json
COPY packages/core /app/packages/core
RUN npm install --omit=dev
COPY tsconfig.base.json /app/tsconfig.base.json
COPY services/api ./

EXPOSE 8787
CMD ["npm", "run", "start"]
