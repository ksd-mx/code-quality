#!/bin/sh

# This script creates a predefined token in SonarQube that all scanners can use
set -e  # Exit on any error
set -x  # Print commands for debugging

echo "Starting token setup script..."

# Wait for SonarQube to be fully up
echo "Waiting for SonarQube to start..."
max_retries=30
counter=0

# First make sure we can reach the SonarQube server
until curl -s -f http://sonarqube:9000 > /dev/null; do
  counter=$((counter+1))
  if [ $counter -ge $max_retries ]; then
    echo "ERROR: Could not connect to SonarQube server"
    exit 1
  fi
  echo "Waiting for SonarQube network connectivity... ($counter/$max_retries)"
  sleep 10
done

echo "SonarQube server is reachable, waiting for it to be fully up..."
counter=0

# Now wait for the system to be fully up
until curl -s -f http://sonarqube:9000/api/system/status | grep -q '"status":"UP"'; do
  counter=$((counter+1))
  if [ $counter -ge $max_retries ]; then
    echo "ERROR: Timed out waiting for SonarQube to start"
    exit 1
  fi
  echo "Waiting for SonarQube to be ready... ($counter/$max_retries)"
  sleep 10
done

echo "SonarQube is up, checking existing tokens..."

# First check if the token already exists
TOKEN_CHECK=$(curl -s -f -u admin:admin "http://sonarqube:9000/api/user_tokens/search")
echo "Existing tokens: $TOKEN_CHECK"

if echo "$TOKEN_CHECK" | grep -q "global-scanner-token"; then
  echo "Token 'global-scanner-token' already exists, no need to recreate."
else
  echo "Creating new global scanner token..."
  
  # Create the token - first try with the fixed value
  TOKEN_RESPONSE=$(curl -v -X POST -u admin:admin "http://sonarqube:9000/api/user_tokens/generate" \
    -d "name=global-scanner-token" \
    -d "login=admin" \
    -d "type=USER_TOKEN" 2>&1)
  
  echo "Token generation response: $TOKEN_RESPONSE"
  
  # Check if token was successfully created
  TOKEN_CHECK_AFTER=$(curl -s -f -u admin:admin "http://sonarqube:9000/api/user_tokens/search")
  echo "Tokens after creation attempt: $TOKEN_CHECK_AFTER"
  
  if echo "$TOKEN_CHECK_AFTER" | grep -q "global-scanner-token"; then
    echo "SUCCESS: Global token was created!"
  else
    echo "ERROR: Failed to create token. API response doesn't show the token was created."
    exit 1
  fi
fi

# Final verification - try to use the scanner with this token
echo "Setup complete. You can now use SonarQube scanners with the global token."