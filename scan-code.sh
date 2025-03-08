#!/bin/bash

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SONAR_HOST="http://sonarqube:9000"
CREDS_DIR="$HOME/.sonarqube"
CREDS_FILE="$CREDS_DIR/credentials"

# Banner
echo -e "${GREEN}"
echo "=================================================="
echo "  SonarQube Code Scanner"
echo "=================================================="
echo -e "${NC}"

# Check if credentials file exists
if [ ! -f "$CREDS_FILE" ]; then
  echo -e "${RED}Error: Credentials file not found at $CREDS_FILE${NC}"
  echo -e "${RED}Please run setup.sh first to initialize SonarQube and credentials.${NC}"
  exit 1
fi

# Load credentials
source "$CREDS_FILE"

# Verify credentials were loaded properly
if [ -z "$SONAR_TOKEN" ] || [ "$SONAR_TOKEN" == "failed_to_generate" ] || [ "$SONAR_TOKEN" == "failed_to_extract" ]; then
  echo -e "${RED}Error: Invalid or missing token in credentials file.${NC}"
  echo -e "${RED}Please run setup.sh again to generate a valid token.${NC}"
  exit 1
fi

# Get source directory (default to current directory if not provided)
if [ -z "$1" ]; then
  SOURCE_DIR=$(pwd)
else
  # Convert to absolute path if relative
  if [[ "$1" = /* ]]; then
    SOURCE_DIR="$1"
  else
    SOURCE_DIR="$(pwd)/$1"
  fi
fi

# Check if directory exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo -e "${RED}Error: Directory '$SOURCE_DIR' does not exist.${NC}"
  exit 1
fi

# Extract the project information from directory name
FOLDER_NAME=$(basename "$SOURCE_DIR")
PROJECT_KEY=$(echo "$FOLDER_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
PROJECT_NAME="$FOLDER_NAME"

echo -e "${YELLOW}Scanning:${NC} $SOURCE_DIR"
echo -e "${YELLOW}Project Key:${NC} $PROJECT_KEY"
echo -e "${YELLOW}Project Name:${NC} $PROJECT_NAME"

# Get SonarQube network name (in case user renamed it)
SONAR_NETWORK=$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' sonarqube 2>/dev/null)

if [ -z "$SONAR_NETWORK" ]; then
  echo -e "${RED}Error: SonarQube container not found. Make sure it's running.${NC}"
  exit 1
fi

# Check if project exists, create it if it doesn't
echo -e "${YELLOW}Checking if project exists...${NC}"

# Use the SonarQube API to check if the project exists
PROJECT_EXISTS=$(curl -s -X GET "$SONAR_HOST/api/projects/search?projects=$PROJECT_KEY" \
  -H "Content-Type: application/json" \
  -u "$SONAR_TOKEN:" | grep -c "\"key\":\"$PROJECT_KEY\"")

if [ "$PROJECT_EXISTS" -eq 0 ]; then
  echo -e "${YELLOW}Project does not exist. Creating project...${NC}"
  
  # Create the project using the SonarQube API
  CREATE_RESPONSE=$(curl -s -X POST "$SONAR_HOST/api/projects/create" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -u "$SONAR_TOKEN:" \
    -d "project=$PROJECT_KEY&name=$PROJECT_NAME")
    
  # Check if project creation was successful
  if [[ $CREATE_RESPONSE == *"error"* ]]; then
    echo -e "${RED}Failed to create project with token. SonarQube returned an error:${NC}"
    echo "$CREATE_RESPONSE"
    
    # Try again with admin password
    echo -e "${YELLOW}Trying with admin credentials instead...${NC}"
    CREATE_RESPONSE=$(curl -s -X POST "$SONAR_HOST/api/projects/create" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -u "$SONAR_USERNAME:$SONAR_PASSWORD" \
      -d "project=$PROJECT_KEY&name=$PROJECT_NAME")
      
    if [[ $CREATE_RESPONSE == *"error"* ]]; then
      echo -e "${RED}Failed to create project with admin credentials:${NC}"
      echo "$CREATE_RESPONSE"
      exit 1
    else
      echo -e "${GREEN}Project created successfully with admin credentials!${NC}"
    fi
  else
    echo -e "${GREEN}Project created successfully!${NC}"
  fi
else
  echo -e "${GREEN}Project already exists.${NC}"
fi

echo -e "${YELLOW}Running scan...${NC}"

# Run scan using Docker with dynamic volume mount
docker run --rm \
  --network="$SONAR_NETWORK" \
  -v "$SOURCE_DIR:/usr/src/code" \
  sonarsource/sonar-scanner-cli \
  sonar-scanner \
  -Dsonar.projectKey="$PROJECT_KEY" \
  -Dsonar.projectName="$PROJECT_NAME" \
  -Dsonar.host.url="$SONAR_HOST" \
  -Dsonar.token="$SONAR_TOKEN" \
  -Dsonar.sources="/usr/src/code"

SCAN_STATUS=$?

if [ $SCAN_STATUS -eq 0 ]; then
  echo -e "${GREEN}Scan completed successfully.${NC}"
  echo -e "View results at: http://localhost:9000/dashboard?id=$PROJECT_KEY"
else
  echo -e "${RED}Scan failed with status code $SCAN_STATUS.${NC}"
  echo -e "Please check the log output above for details."
fi