# Portable Code Quality Scanner

A professional-grade, ready-to-use SonarQube setup that makes code quality analysis effortless for any development team.

## Features

- **One-Click Setup**: Automated installation and configuration
- **Persistent Storage**: Your scan history and configuration persists between restarts
- **Project Auto-Creation**: Automatically creates new projects based on directory names
- **Simple Scanning**: Just point to your code directory and get results

## Prerequisites

- Docker
- Docker Compose
- Bash terminal environment

## Getting Started

### Step 1: Clone this repository

```bash
git clone https://github.com/ksd-mx/code-quality.git
cd code-quality
```

### Step 2: Run the setup script

```bash
chmod +x setup.sh
./setup.sh
```

This script will:
- Start SonarQube and PostgreSQL containers
- Configure a secure admin password
- Generate an API token for scanning
- Save credentials to `~/.sonarqube/credentials`

**Note**: SonarQube takes a few minutes to fully initialize on first startup.

### Step 3: Scan your code

```bash
chmod +x scan-code.sh
./scan-code.sh [path/to/your/code]
```

If you don't specify a path, the script will scan the current directory.

## Viewing Results

After scanning, your results will be available at:

```
http://localhost:9000/dashboard?id=your-project-key
```

Where `your-project-key` is derived from your directory name.

## How It Works

### Docker Compose Configuration

The `docker-compose.yaml` file sets up:
- SonarQube server (latest version)
- PostgreSQL database
- Persistent volumes for data, logs, and extensions
- Network configuration

### Credentials Management

All credentials are securely stored in `~/.sonarqube/credentials` with proper file permissions:
- Admin username and password
- API token for automated scanning
- SonarQube URL

### Project Handling

The scanning script:
1. Checks if your project exists in SonarQube
2. Creates it automatically if needed
3. Runs the scan with the appropriate configuration
4. Provides a direct link to view results

## Customization

### Changing PostgreSQL Password

Edit the `docker-compose.yaml` file and modify:
```yaml
environment:
  - POSTGRES_PASSWORD=your-new-password
  - SONAR_JDBC_PASSWORD=your-new-password
```

Then restart the stack with `docker-compose down && docker-compose up -d`.

### Adding Analysis Parameters

Edit the `scan-code.sh` file to add additional SonarQube parameters:

```bash
docker run --rm \
  --network="$SONAR_NETWORK" \
  -v "$SOURCE_DIR:/usr/src/code" \
  sonarsource/sonar-scanner-cli \
  sonar-scanner \
  -Dsonar.projectKey="$PROJECT_KEY" \
  -Dsonar.projectName="$PROJECT_NAME" \
  -Dsonar.host.url="$SONAR_HOST" \
  -Dsonar.token="$SONAR_TOKEN" \
  -Dsonar.sources="/usr/src/code" \
  -Dsonar.your.custom.property="value"  # Add your custom properties here
```

## Troubleshooting

### SonarQube Fails to Start

If SonarQube fails to start, check the logs with:

```bash
docker-compose logs sonarqube
```

Common issues include:
- Memory limits (increase vm.max_map_count)
- Port conflicts (change port in docker-compose.yaml)

### Scan Failures

If scanning fails:
1. Ensure SonarQube is fully running
2. Check credentials in `~/.sonarqube/credentials`
3. Try running `./setup.sh` again to regenerate the token

## Maintaining Your Setup

### Updating SonarQube

To update SonarQube to the latest version, use the provided update script:

```bash
chmod +x update.sh
./update.sh
```

This script will:
- Confirm you want to proceed with the update
- Backup your credentials
- Stop current containers
- Pull the latest images
- Restart the services
- Verify that SonarQube started successfully

### Removing SonarQube

If you want to completely remove SonarQube from your system, use the cleanup script:

```bash
chmod +x cleanup.sh
./cleanup.sh
```

This script will:
- Ask for confirmation (type 'DELETE' to proceed)
- Stop and remove all containers
- Delete all Docker volumes
- Remove credentials and scanner cache

## Security Considerations

- Credentials are stored with 600 permissions (user read/write only)
- The credentials directory has 700 permissions
- This setup is for local development only and not intended for production use

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- [SonarQube](https://www.sonarqube.org/) for their code quality tool
- [Docker](https://www.docker.com/) for containerization
- The open source community for inspiration