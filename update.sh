#!/bin/bash

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CREDS_FILE="$HOME/.sonarqube/credentials"

# Banner
echo -e "${GREEN}"
echo "=================================================="
echo "  SonarQube Environment Update"
echo "=================================================="
echo -e "${NC}"

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker is not installed.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose is not installed.${NC}"
    exit 1
fi

# Check if SonarQube is currently installed
if ! docker ps -a | grep -q sonarqube; then
    echo -e "${RED}SonarQube doesn't appear to be installed. Please run setup.sh first.${NC}"
    exit 1
fi

# Check for credentials file
if [ ! -f "$CREDS_FILE" ]; then
    echo -e "${RED}Credentials file not found at $CREDS_FILE${NC}"
    echo -e "${RED}Please run setup.sh first to initialize SonarQube and credentials.${NC}"
    exit 1
fi

# Security confirmation
echo -e "${YELLOW}This will update SonarQube to the latest version.${NC}"
echo -e "${YELLOW}Your existing data and configurations will be preserved.${NC}"
echo ""
echo -e "${YELLOW}Do you want to proceed? (y/n)${NC}"
read -r CONFIRMATION

if [[ ! "$CONFIRMATION" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Update canceled.${NC}"
    exit 0
fi

echo -e "${YELLOW}Starting update process...${NC}"

# Check if we need to backup credentials
if [ -f "$CREDS_FILE" ]; then
    echo -e "${YELLOW}Backing up credentials...${NC}"
    cp "$CREDS_FILE" "$CREDS_FILE.bak"
    echo -e "${GREEN}Credentials backed up to $CREDS_FILE.bak${NC}"
fi

# Stop the current containers
echo -e "${YELLOW}Stopping current containers...${NC}"
docker-compose down
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to stop containers. Update aborted.${NC}"
    exit 1
fi
echo -e "${GREEN}Containers stopped successfully.${NC}"

# Pull latest images
echo -e "${YELLOW}Pulling latest Docker images...${NC}"
docker-compose pull
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to pull latest images. Update aborted.${NC}"
    echo -e "${YELLOW}Attempting to restart with existing images...${NC}"
    docker-compose up -d
    exit 1
fi
echo -e "${GREEN}Latest images pulled successfully.${NC}"

# Start containers with new images
echo -e "${YELLOW}Starting containers with updated images...${NC}"
docker-compose up -d
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to start containers with new images.${NC}"
    echo -e "${RED}Please check logs and try again.${NC}"
    exit 1
fi
echo -e "${GREEN}Containers started successfully with updated images.${NC}"

# Wait for SonarQube to be ready
echo -e "${YELLOW}Waiting for SonarQube to be fully operational...${NC}"
# Wait for SonarQube to be ready
while true; do
    # Check if the SonarQube web server is up
    if curl -s http://localhost:9000 > /dev/null; then
        # Check if the login page is accessible
        if curl -s http://localhost:9000/api/system/status | grep -q "UP"; then
            echo -e "${GREEN}SonarQube is up and running!${NC}"
            break
        fi
    fi
    echo -e "${YELLOW}Waiting for SonarQube to start (this may take a few minutes)...${NC}"
    sleep 10
done

echo -e "${GREEN}"
echo "=================================================="
echo "  Update Complete!"
echo "=================================================="
echo -e "${NC}"
echo "SonarQube has been updated to the latest version."
echo "URL: http://localhost:9000"
echo "Your existing projects and scan history have been preserved."