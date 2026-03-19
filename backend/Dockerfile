FROM node:20

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npx prisma generate --schema=src/db/schema.prisma

EXPOSE 8080

CMD ["npm", "start"]