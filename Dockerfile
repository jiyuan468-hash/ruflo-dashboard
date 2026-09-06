FROM node:20-slim

RUN npm install -g ruflo@latest

WORKDIR /app

EXPOSE 3000

ENV MCP_TRANSPORT=http
ENV MCP_HOST=0.0.0.0
ENV MCP_PORT=3000
ENV NODE_ENV=production

CMD ["ruflo", "mcp", "start", "-t", "http", "-h", "0.0.0.0", "-p", "3000"]
