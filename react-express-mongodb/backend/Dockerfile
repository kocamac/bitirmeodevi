# syntax=docker/dockerfile:1.4

FROM node:lts-buster-slim

# Create app directory
WORKDIR /usr/src/app

COPY package*.json /usr/src/app/
# COPY package-lock.json /usr/src/app/package-lock.json

RUN npm ci

COPY . /usr/src/app

EXPOSE 3000

CMD [ "npm", "run", "dev" ]