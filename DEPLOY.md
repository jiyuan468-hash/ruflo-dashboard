# Ruflo MCP Server Deployment

## ✅ 已部署

**服务地址：** https://ruflo-mcp.onrender.com
**状态：** Live（免费实例，会休眠）

## 部署信息

| 项目 | 详情 |
|------|------|
| 服务名 | ruflo-mcp |
| 域名 | ruflo-mcp.onrender.com |
| 区域 | Singapore（东南亚） |
| 计费 | 免费（\/月） |
| 实例 | 0.1 CPU，512MB RAM |

## 注意

- 免费实例会休眠，首次访问需等待 30~60 秒
- 如需保持在线，可升级至 \/月 实例
- 基础编排功能无需 API Key
- LLM 路由需配置 ANTHROPIC_API_KEY 或 OPENAI_API_KEY

## How Others Use Your Server

Once deployed, others can connect to your MCP server:

```json
{
  "mcpServers": {
    "ruflo": {
      "command": "http",
      "url": "https://ruflo-mcp.onrender.com"
    }
  }
}
```

## Deploy to Railway (Free trial)
1. Go to https://railway.app
2. Import from GitHub repo
3. Railway will auto-detect Dockerfile
4. Click Deploy
