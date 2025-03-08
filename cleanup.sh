#!/bin/bash

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CREDS_DIR="$HOME/.sonarqube"
CREDS_FILE="$CREDS_DIR/credentials"

# Banner
echo -e "${RED}"
echo "=================================================="
echo "  SonarQube Environment Cleanup"
echo "=================================================="
echo -e "${NC}"

# Security confirmation
echo -e "${RED}WARNING: This will completely remove all SonarQube containers, volumes, and credentials.${NC}"
echo -e "${RED}All scan history and configuration will be permanently deleted.${NC}"
echo ""
echo -e "${YELLOW}Please type 'DELETE' (all caps) to confirm:${NC}"
read -r CONFIRMATION

if [ "$CONFIRMATION" != "DELETE" ]; then
    echo -e "${GREEN}Cleanup canceled.${NC}"
    exit 0
fi

echo -e "${YELLOW}Beginning cleanup process...${NC}"

# Step 1: Stop and remove containers
echo -e "${YELLOW}Stopping and removing Docker containers...${NC}"
docker-compose down 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Containers stopped and removed successfully.${NC}"
else
    echo -e "${YELLOW}No containers found or docker-compose failed.${NC}"
fi

# Step 2: Remove Docker volumes
echo -e "${YELLOW}Removing Docker volumes...${NC}"
docker volume rm sonarqube_data sonarqube_logs sonarqube_extensions postgres_data scanner-cache 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Volumes removed successfully.${NC}"
else
    echo -e "${YELLOW}Volumes may not exist or could not be removed.${NC}"
fi

# Step 3: Remove credentials
if [ -f "$CREDS_FILE" ]; then
    echo -e "${YELLOW}Removing credentials file...${NC}"
    rm -f "$CREDS_FILE"
    echo -e "${GREEN}Credentials file removed.${NC}"
fi

if [ -d "$CREDS_DIR" ]; then
    echo -e "${YELLOW}Removing credentials directory...${NC}"
    rm -rf "$CREDS_DIR"
    echo -e "${GREEN}Credentials directory removed.${NC}"
fi

# Step 4: Clean local scanner cache
if [ -d "scanner-cache" ]; then
    echo -e "${YELLOW}Removing scanner cache directory...${NC}"
    rm -rf scanner-cache
    echo -e "${GREEN}Scanner cache removed.${NC}"
fi

echo -e "${GREEN}"
echo "=================================================="
echo "  Cleanup Complete!"
echo "=================================================="
echo -e "${NC}"
echo "All SonarQube components have been removed from your system."
echo "If you want to reinstall, simply run setup.sh again."