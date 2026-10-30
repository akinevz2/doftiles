# SonarQube Local Setup Guide

This guide covers setting up a completely local SonarQube Server and MCP server using Docker.

## Overview

This setup provides:
- **Local SonarQube Server** - Completely self-contained running in Docker containers
- **Local MCP Server** - Docker-based Model Context Protocol server for AI agents
- **Persistent Data** - All data stored in Docker volumes
- **Automatic Management** - Start/stop scripts and health monitoring

## Prerequisites

- Docker and Docker Compose installed
- Docker configured to run as your user (not root) for easier management
- No private keys or certificates required

## Quick Start

### 1. Initialize the Dots Repository

```bash
cd ~/dots
make install
```

This will deploy the configuration files to your home directory.

### 2. Create a SonarQube Token

1. Access your local SonarQube at http://localhost:9000
2. Login with default credentials: `admin` / `admin`
3. Navigate to **User** > **My Account** > **Generate Tokens**
4. Name the token (e.g., "opencode-mcp")
5. Copy the token - you'll need it in the next step

### 3. Set Environment Variables

Add these lines to your shell configuration (`.bashrc`, `.zshrc`, or `.profile`):

```bash
# SonarQube Local Server Token (required)
export SONARQUBE_TOKEN="squ_YourGeneratedTokenHere"

# SonarQube URL (optional for local, already set below)
export SONARQUBE_URL="http://localhost:9000"
```

OR create a `.env` file in `~/dots/llms/` directory:
```bash
SONARQUBE_TOKEN=squ_YourGeneratedTokenHere
SONARQUBE_URL=http://localhost:9000
```

### 4. Start the SonarQube Server

```bash
cd ~/dots/llms
docker-compose up -d
```

This will start both the PostgreSQL database and SonarQube server.

### 5. Access SonarQube

Open your web browser to: http://localhost:9000

### 6. Configure OpenCode MCP

Edit `/home/kine/dots/llms/.config/opencode/opencode.jsonc`:

1. Enable the local SonarQube MCP server:
   ```jsonc
   "sonarqube-local": {
     "enabled": true
   }
   ```

2. If you prefer the cloud version, enable instead:
   ```jsonc
   "sonarqube-cloud": {
     "enabled": true
   }
   ```

3. Deploy the configuration:
   ```bash
   cd ~/dots
   make opencode
   ```

## Managing the Services

### Check Service Status

```bash
# Check all containers
docker-compose ps

# View SonarQube logs
docker-compose logs -f sonarqube

# View database logs
docker-compose logs -f sonarqube-db
```

### Stop the Services

```bash
docker-compose down
```

### Start the Services

```bash
docker-compose up -d
```

### Restart SonarQube

```bash
docker-compose restart sonarqube
```

### Access SonarQube CLI

```bash
docker exec -it sonarqube-server sonar-cli help
```

## Default Credentials

Initial access to SonarQube:
- **URL**: http://localhost:9000
- **Username**: `admin`
- **Password**: `admin`

**IMPORTANT**: Change the default password after first login!

## Data Storage

All data is persisted in Docker volumes:
- `/home/kine/.local/share/docker/volumes/sonarqube_postgres_data/`
- `/home/kine/.local/share/docker/volumes/sonarqube_data/`
- `/home/kine/.local/share/docker/volumes/sonarqube_extensions/`
- `/home/kine/.local/share/docker/volumes/sonarqube_logs/`
- `/home/kine/.local/share/docker/volumes/sonarqube_temp/`

You can view these volumes:
```bash
docker volume ls | grep sonarqube
```

## Verifying the MCP Server

Once configured and enabled, the SonarQube MCP server will be accessible through MCP-compatible clients.

### Manual Test

```bash
docker run --rm \
  -e SONARQUBE_TOKEN="$SONARQUBE_TOKEN" \
  -e SONARQUBE_URL="http://localhost:9000" \
  sonarsource/sonarqube-mcp:latest /opt/sonarqube-mcp/sonarqube-mcp-server
```

## Troubleshooting

### SonarQube Not Starting

1. Check logs:
   ```bash
   docker-compose logs sonarqube
   ```

2. Verify database is healthy:
   ```bash
   docker-compose ps sonarqube-db
   docker-compose logs sonarqube-db
   ```

3. Common issues:
   - **Low memory**: SonarQube requires at least 2GB RAM
   - **Port conflict**: Ensure port 9000 is not in use
   - **Database connection**: Check JDBC URL is correct

### MCP Server Connection Issues

1. Verify SonarQube is running:
   ```bash
   curl http://localhost:9000/api/system/status
   ```

2. Check token is set correctly:
   ```bash
   echo $SONARQUBE_TOKEN
   ```

3. Check MCP configuration in `opencode.jsonc`:
   ```bash
   cat ~/.config/opencode/opencode.jsonc | grep sonarqube
   ```

### Network Issues

The MCP server tries to connect to the Docker bridge network (`docker-llms_default`). If you encounter network issues:

1. Verify the network exists:
   ```bash
   docker network ls | grep docker-llms_default
   ```

2. Check container network:
   ```bash
   docker inspect sonarqube-server | grep Networks
   docker inspect sonarqube-mcp-server | grep Networks
   ```

## Cleanup

### Remove All SonarQube Data

```bash
docker-compose down -v
```

This removes all containers and data volumes. **Warning**: This is permanent!

### Remove Only Containers

```bash
docker-compose down
```

This preserves the data volumes but removes containers.

## Advanced Configuration

### Custom Database Password

Modify `docker-compose.yml`:
```yaml
environment:
  - POSTGRES_PASSWORD=YourCustomPassword
```

### Different Port

Modify `docker-compose.yml`:
```yaml
ports:
  - "8080:9000"
```

Then update `SONARQUBE_URL` environment variable: `http://localhost:8080`

### Enable Cloud Version

In `opencode.jsonc`:
```jsonc
"sonarqube-cloud": {
  "enabled": true,
  "env": {
    "SONARQUBE_TOKEN": "${SONARQUBE_CLOUD_TOKEN}",
    "SONARQUBE_ORG": "${SONARQUBE_CLOUD_ORG}",
    "SONARQUBE_URL": "${SONARQUBE_CLOUD_URL}"
  }
}
```

## Security Notes

- Keep your `SONARQUBE_TOKEN` secure - it has the same permissions as an admin account
- Change the default SonarQube password (`admin`/`admin`) after first login
- Consider exposing the server only locally (http://localhost:9000) for private projects
- For production use, configure authentication, SSL/TLS, and network restrictions

## Resources

- [SonarQube Documentation](https://docs.sonarsource.com/sonarqube-server/latest/)
- [SonarQube Docker Compose Example](https://github.com/SonarSource/docker-sonarqube)
- [MCP Server Documentation](https://docs.sonarsource.com/sonarqube-mcp-server/)
