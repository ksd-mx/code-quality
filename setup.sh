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
echo -e "${GREEN}"
echo "=================================================="
echo "  SonarQube Local Development Environment Setup"
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

# Create credentials directory
mkdir -p "$CREDS_DIR"
chmod 700 "$CREDS_DIR"
echo -e "${GREEN}Created credentials directory: $CREDS_DIR${NC}"

# Get new admin password from user
while true; do
    echo -e "${YELLOW}Enter a new admin password for SonarQube:${NC}"
    echo -e "${YELLOW}(Must be at least 12 characters, include 1 special character, 1 number, and 1 capital letter)${NC}"
    read -s SONAR_PASSWORD
    echo

    # Password validation
    if [[ ${#SONAR_PASSWORD} -lt 12 ]]; then
        echo -e "${RED}Password must be at least 12 characters.${NC}"
        continue
    fi
    
    if ! [[ $SONAR_PASSWORD =~ [A-Z] ]]; then
        echo -e "${RED}Password must contain at least one capital letter.${NC}"
        continue
    fi
    
    if ! [[ $SONAR_PASSWORD =~ [0-9] ]]; then
        echo -e "${RED}Password must contain at least one number.${NC}"
        continue
    fi
    
    if ! [[ $SONAR_PASSWORD =~ [[:punct:]] ]]; then
        echo -e "${RED}Password must contain at least one special character.${NC}"
        continue
    fi
    
    # Confirm password
    echo -e "${YELLOW}Confirm password:${NC}"
    read -s SONAR_PASSWORD_CONFIRM
    echo
    
    if [[ "$SONAR_PASSWORD" != "$SONAR_PASSWORD_CONFIRM" ]]; then
        echo -e "${RED}Passwords do not match.${NC}"
        continue
    fi
    
    break
done

echo -e "${GREEN}Starting Docker Compose stack...${NC}"
docker-compose up -d

# Create directory for scanner cache
mkdir -p scanner-cache

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

# Give SonarQube a bit more time to fully initialize
sleep 5

echo -e "${YELLOW}Updating admin password...${NC}"

# Update admin password using curl (first login uses default admin/admin)
CHANGE_PASSWORD_RESPONSE=$(curl -s -X POST "http://localhost:9000/api/users/change_password" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u admin:admin \
  -d "login=admin&previousPassword=admin&password=$SONAR_PASSWORD")

if [[ $CHANGE_PASSWORD_RESPONSE == *"error"* ]]; then
    echo -e "${RED}Failed to change admin password. SonarQube returned an error.${NC}"
    echo "$CHANGE_PASSWORD_RESPONSE"
    exit 1
fi

echo -e "${GREEN}Admin password updated successfully!${NC}"

# Check for existing tokens and revoke if necessary
echo -e "${YELLOW}Checking for existing tokens...${NC}"
TOKEN_NAME="ci-token"

# Check if a token with this name already exists
TOKEN_EXISTS=$(curl -s -X GET "http://localhost:9000/api/user_tokens/search" \
  -u "admin:$SONAR_PASSWORD" | grep -c "\"name\":\"$TOKEN_NAME\"")

# If token exists, revoke it first
if [ "$TOKEN_EXISTS" -gt 0 ]; then
  echo -e "${YELLOW}Token '$TOKEN_NAME' already exists. Revoking it...${NC}"
  REVOKE_RESPONSE=$(curl -s -X POST "http://localhost:9000/api/user_tokens/revoke" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -u "admin:$SONAR_PASSWORD" \
    -d "name=$TOKEN_NAME")
  
  if [[ $REVOKE_RESPONSE == *"error"* ]]; then
    echo -e "${RED}Failed to revoke existing token.${NC}"
    echo "$REVOKE_RESPONSE"
    exit 1
  else
    echo -e "${GREEN}Existing token revoked successfully.${NC}"
  fi
fi

# Generate new token
echo -e "${YELLOW}Generating a new SonarQube user token...${NC}"
TOKEN_RESPONSE=$(curl -s -X POST "http://localhost:9000/api/user_tokens/generate" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "admin:$SONAR_PASSWORD" \
  -d "name=$TOKEN_NAME")

if [[ $TOKEN_RESPONSE == *"error"* ]]; then
    echo -e "${RED}Failed to generate user token. SonarQube returned an error.${NC}"
    echo "$TOKEN_RESPONSE"
    TOKEN="failed_to_generate"
else
    # Extract token from response
    TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    if [ -z "$TOKEN" ]; then
        echo -e "${RED}Failed to extract token from response.${NC}"
        TOKEN="failed_to_extract"
    else
        echo -e "${GREEN}Token generated successfully!${NC}"
    fi
fi

# Create credentials file
cat > "$CREDS_FILE" << EOF
SONAR_USERNAME=admin
SONAR_PASSWORD=$SONAR_PASSWORD
SONAR_TOKEN=$TOKEN
SONAR_URL=http://localhost:9000
EOF

chmod 600 "$CREDS_FILE"
echo -e "${GREEN}Credentials saved to $CREDS_FILE${NC}"

echo -e "${GREEN}"
echo "=================================================="
echo "  Setup Complete!"
echo "=================================================="
echo -e "${NC}"
echo "SonarQube URL: http://localhost:9000"
echo "Username: admin"
echo "Password and token stored in: $CREDS_FILE"
echo ""
echo "You can now use scan-code.sh to scan your projects:"
echo "./scan-code.sh [SOURCE_DIR]"