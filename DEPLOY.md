# Ruflo MCP Server Deployment

## Deploy to Render (Free)
1. Go to https://render.com
2. Sign up / Log in
3. Click New + → Web Service
4. Connect GitHub repo: jiyuan468-hash/ruflo-dashboard
5. Configure:
   - Name: ruflo-mcp
   - Environment: Docker
   - Region: Choose closest to you
6. Click Create Web Service

## Deploy to Railway (Free trial)
1. Go to https://railway.app
2. Import from GitHub repo
3. Railway will auto-detect Dockerfile
4. Click Deploy

## Deploy to Railway (Free trial)

## How Others Use Your Server

Once deployed, others can connect to your MCP server:

```json
{"mcpServers": {"ruflo": {"command": "http", "url": "https://your-service.onrender.com"}}}
```

## Deploy to Railway (Free trial)
1. Go to https://railway.app
2. Import from GitHub repo
3. Railway will auto-detect Dockerfile
4. Click Deploy

## How Others Use Your Server

```json
{"mcpServers": {"ruflo": {"command": "http", "url": "https://your-service.onrender.com"}}}
```
