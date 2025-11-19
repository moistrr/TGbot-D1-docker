FROM node:20-alpine
WORKDIR /app
# 安装构建依赖 (sqlite 需要)
RUN apk add --no-cache python3 make g++
COPY package.json ./
RUN npm install --omit=dev
COPY . .
RUN mkdir -p /app/data
EXPOSE 3000
CMD ["npm", "start"]