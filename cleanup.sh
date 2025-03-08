#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}====== SonarQube Cleanup ======${NC}"
echo -e "${YELLOW}This script will remove all SonarQube components from your machine.${NC}"
echo -e "${YELLOW}This includes:${NC}"
echo -e "  - SonarQube Docker containers"
echo -e "  - SonarQube Docker volumes"
echo -e "  - SonarQube Docker networks"
echo -e "  - SonarQube directory in your home folder"
echo -e "  - Any scanner configuration files in the current directory"
echo -e ""
echo -e "${RED}WARNING: All SonarQube data will be lost!${NC}"
echo -e ""

# Ask for confirmation
read -p "Are you sure you want to proceed? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Cleanup canceled.${NC}"
    exit 0
fi

# Step 1: Stop and remove SonarQube containers
echo -e "${BLUE}Stopping and removing SonarQube containers...${NC}"
SONARQUBE_HOME="$HOME/.sonarqube"

if [ -d "$SONARQUBE_HOME" ]; then
    (cd "$SONARQUBE_HOME" && docker-compose down -v --remove-orphans)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SonarQube containers stopped and removed.${NC}"
    else
        echo -e "${YELLOW}There may have been issues stopping SonarQube containers. Continuing cleanup...${NC}"
    fi
else
    echo -e "${YELLOW}SonarQube directory not found in $SONARQUBE_HOME. Skipping container cleanup.${NC}"
fi

# Step 2: Remove additional Docker components
echo -e "${BLUE}Removing any remaining SonarQube Docker components...${NC}"

# Remove containers with 'sonarqube' in the name
CONTAINERS=$(docker ps -a | grep -i sonarqube | awk '{print $1}')
if [ -n "$CONTAINERS" ]; then
    echo -e "${BLUE}Removing containers: $CONTAINERS${NC}"
    docker rm -f $CONTAINERS 2>/dev/null
    echo -e "${GREEN}SonarQube containers removed.${NC}"
else
    echo -e "${GREEN}No SonarQube containers found.${NC}"
fi

# Remove volumes with 'sonarqube' in the name
VOLUMES=$(docker volume ls | grep -i sonarqube | awk '{print $2}')
if [ -n "$VOLUMES" ]; then
    echo -e "${BLUE}Removing volumes: $VOLUMES${NC}"
    docker volume rm $VOLUMES 2>/dev/null
    echo -e "${GREEN}SonarQube volumes removed.${NC}"
else
    echo -e "${GREEN}No SonarQube volumes found.${NC}"
fi

# Remove networks with 'sonarqube' in the name
NETWORKS=$(docker network ls | grep -i sonarqube | awk '{print $2}')
if [ -n "$NETWORKS" ]; then
    echo -e "${BLUE}Removing networks: $NETWORKS${NC}"
    docker network rm $NETWORKS 2>/dev/null
    echo -e "${GREEN}SonarQube networks removed.${NC}"
else
    echo -e "${GREEN}No SonarQube networks found.${NC}"
fi

# Step 3: Remove SonarQube directory
echo -e "${BLUE}Removing SonarQube directory...${NC}"
if [ -d "$SONARQUBE_HOME" ]; then
    rm -rf "$SONARQUBE_HOME"
    echo -e "${GREEN}SonarQube directory removed.${NC}"
else
    echo -e "${GREEN}SonarQube directory not found. Already cleaned up.${NC}"
fi

echo -e "${GREEN}====== Cleanup Complete ======${NC}"
echo -e "${GREEN}All SonarQube components have been removed from your system.${NC}"
echo -e "${YELLOW}Note: You may still have the 'scan.sh' and 'cleanup.sh' scripts in your current directory.${NC}"
echo -e "${YELLOW}You can remove them manually if they are no longer needed.${NC}"