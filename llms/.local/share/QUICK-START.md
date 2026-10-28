# SonarQube Local Setup - Quick Reference

## 3-Step Setup

```bash
# 1. Initialize your dots
cd ~/dots
make install

# 2. Create a token in SonarQube (admin/admin)
#    User > My Account > Generate Tokens

# 3. Set environment variables
export SONARQUBE_TOKEN="YourGeneratedToken"
export SONARQUBE_URL="http://localhost:9000"

# OR create a .env file:
# cat > ~/dots/llms/.env << 'EOF'
# SONARQUBE_TOKEN=YourGeneratedToken
# SONARQUBE_URL=http://localhost:9000
# EOF
```

## Start SonarQube

```bash
cd ~/dots/llms
docker-compose up -d
```

## Manage Services

```bash
# Status
docker-compose ps

# Logs
docker-compose logs -f sonarqube

# Stop
docker-compose down
```

## Access SonarQube

```
URL: http://localhost:9000
User: admin
Pass: admin (change after login!)
```

## MCP Configuration

Edit `~/dots/llms/.config/opencode/opencode.jsonc`:

```jsonc
"mcp": {
  "sonarqube-local": {
    "enabled": true  // Uncomment to enable
  }
}
# OR
  "sonarqube-cloud": {
    "enabled": true  // Uncomment for cloud version
  }
}
```

## Management Script

```bash
cd ~/dots/llms
./.local/bin/sonarqube-mcp-manager help
./.local/bin/sonarqube-mcp-manager start
./.local/bin/sonarqube-mcp-manager logs
./.local/bin/sonarqube-mcp-manager status
```

## Clean Data

```bash
docker-compose down -v  # Removes all data (DESTRUCTIVE!)
```

## Troubleshooting

```bash
# Check if running
docker-compose ps

# View logs (critical for troubleshooting)
docker-compose logs sonarqube

# Test connectivity
curl http://localhost:9000/api/system/status

# Check memory (requires at least 2GB)
free -h
```

## Default Credentials

- **Server**: http://localhost:9000
- **Admin**: admin / admin
- **Token**: Generate in UI (User > My Account > Generate Tokens)

## Files Created

- `docker-compose.yml` - Service definitions
- `SONARQUBE-LOCAL-SETUP.md` - Full documentation
- `QUICK-START.md` - Quick reference
- `opencode.jsonc` - Updated MCP configuration
- `.local/bin/sonarqube-mcp-wrapper` - MCP server wrapper
- `.local/bin/sonarqube-mcp-manager` - Management script

## Version Info

- **SonarQube**: latest (updates automatically)
- **Database**: postgres:12-alpine
- **MCP Server**: sonarsource/sonarqube-mcp:latest
- **Docker Compose**: 3.8

## Support

See `SONARQUBE-LOCAL-SETUP.md` for full documentation.

---

**No private keys required! Only a simple token from your SonarQube instance.** 🎉
