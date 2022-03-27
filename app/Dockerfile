FROM node:15

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm ci --only-production && npm run build

EXPOSE 8080
CMD ["npm", "start"]
