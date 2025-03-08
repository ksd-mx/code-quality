#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default project key and name from directory name
DEFAULT_PROJECT_KEY=$(basename $(pwd) | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
DEFAULT_PROJECT_NAME=$(basename $(pwd))

# Parse command line options
PROJECT_KEY=$DEFAULT_PROJECT_KEY
PROJECT_NAME=$DEFAULT_PROJECT_NAME

print_usage() {
  echo "Usage: ./scan.sh [options]"
  echo ""
  echo "Options:"
  echo "  -k, --key KEY         Project key (default: directory name)"
  echo "  -n, --name NAME       Project name (default: directory name)"
  echo "  -h, --help            Show this help message"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -k|--key)
      PROJECT_KEY="$2"
      shift 2
      ;;
    -n|--name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      print_usage
      exit 1
      ;;
  esac
done

# Check if SonarQube docker-compose.yml exists in the parent directory
SONARQUBE_PATH="../sonarqube"
if [ ! -f "$SONARQUBE_PATH/docker-compose.yml" ]; then
  # Create the sonarqube directory and files if they don't exist
  echo -e "${BLUE}SonarQube server setup not found. Creating it in $SONARQUBE_PATH...${NC}"
  mkdir -p "$SONARQUBE_PATH"
  
  # Create docker-compose.yml in the SonarQube directory
  cat > "$SONARQUBE_PATH/docker-compose.yml" << 'EOF'
version: '3'
services:
  sonarqube:
    image: sonarqube:latest
    ports:
      - "9000:9000"
    environment:
      - SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_logs:/opt/sonarqube/logs
      - sonarqube_extensions:/opt/sonarqube/extensions
    restart: unless-stopped

volumes:
  sonarqube_data:
  sonarqube_logs:
  sonarqube_extensions:
EOF
  
  # Start SonarQube
  echo -e "${BLUE}Starting SonarQube server...${NC}"
  (cd "$SONARQUBE_PATH" && docker-compose up -d)
  
  # Wait for SonarQube to start
  echo -e "${BLUE}Waiting for SonarQube to initialize (this may take a minute)...${NC}"
  until curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; do
    echo -n "."
    sleep 5
  done
  echo ""
  
  # Set admin password to admin (in case it asks to change)
  curl -X POST -u admin:admin "http://localhost:9000/api/users/change_password" \
    -d "login=admin&previousPassword=admin&password=admin"
    
  echo -e "${GREEN}SonarQube server is now running at http://localhost:9000${NC}"
  echo -e "${GREEN}Default login: admin/admin${NC}"
fi

# Detect project type and create appropriate parameters
echo -e "${BLUE}Detecting project type...${NC}"

# Initialize scanner command with basic parameters
SCANNER_COMMAND="sonar-scanner -Dsonar.projectKey=$PROJECT_KEY -Dsonar.projectName=\"$PROJECT_NAME\""

# Function to detect specific file patterns
has_file_pattern() {
  find . -maxdepth 2 -name "$1" | grep -q .
}

# Detect Node.js/JavaScript project
if [ -f "package.json" ]; then
  echo -e "${GREEN}Detected Node.js/JavaScript project${NC}"
  SCANNER_COMMAND+=" -Dsonar.sources=."
  SCANNER_COMMAND+=" -Dsonar.exclusions=**/node_modules/**,**/dist/**,**/build/**,**/coverage/**,**/*.test.js,**/*.spec.js"
  
  # Check for TypeScript
  if [ -f "tsconfig.json" ]; then
    echo -e "${GREEN}Detected TypeScript configuration${NC}"
    SCANNER_COMMAND+=" -Dsonar.typescript.tsconfigPath=./tsconfig.json"
  fi
  
  # Check for Jest coverage
  if [ -d "coverage" ] && [ -f "coverage/lcov.info" ]; then
    echo -e "${GREEN}Detected Jest coverage reports${NC}"
    SCANNER_COMMAND+=" -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info"
    SCANNER_COMMAND+=" -Dsonar.coverage.exclusions=**/*.test.js,**/*.spec.js,**/*.test.ts,**/*.spec.ts,**/tests/**,**/test/**"
  fi
fi

# Detect Java project
if [ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -d "src/main/java" ]; then
  echo -e "${GREEN}Detected Java project${NC}"
  
  # Check for Maven
  if [ -f "pom.xml" ]; then
    echo -e "${GREEN}Detected Maven project${NC}"
    SCANNER_COMMAND+=" -Dsonar.java.binaries=target/classes"
    SCANNER_COMMAND+=" -Dsonar.java.test.binaries=target/test-classes"
    
    # Check if Maven wrapper exists, use it to build the project
    if [ -f "mvnw" ]; then
      echo -e "${BLUE}Building project with Maven wrapper...${NC}"
      ./mvnw clean package -DskipTests
    elif command -v mvn > /dev/null; then
      echo -e "${BLUE}Building project with Maven...${NC}"
      mvn clean package -DskipTests
    fi
  fi
  
  # Check for Gradle
  if [ -f "build.gradle" ]; then
    echo -e "${GREEN}Detected Gradle project${NC}"
    SCANNER_COMMAND+=" -Dsonar.java.binaries=build/classes"
    
    # Check if Gradle wrapper exists, use it to build the project
    if [ -f "gradlew" ]; then
      echo -e "${BLUE}Building project with Gradle wrapper...${NC}"
      ./gradlew build -x test
    elif command -v gradle > /dev/null; then
      echo -e "${BLUE}Building project with Gradle...${NC}"
      gradle build -x test
    fi
  fi
  
  # Add jacoco coverage if exists
  if [ -f "target/site/jacoco/jacoco.xml" ]; then
    echo -e "${GREEN}Detected JaCoCo coverage reports${NC}"
    SCANNER_COMMAND+=" -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml"
  fi
fi

# Detect Python project
if [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "Pipfile" ]; then
  echo -e "${GREEN}Detected Python project${NC}"
  SCANNER_COMMAND+=" -Dsonar.python.version=3"
  SCANNER_COMMAND+=" -Dsonar.sources=."
  
  # Look for coverage files
  if [ -f "coverage.xml" ]; then
    echo -e "${GREEN}Detected Python coverage reports${NC}"
    SCANNER_COMMAND+=" -Dsonar.python.coverage.reportPaths=coverage.xml"
  fi
  
  # Add common Python exclusions
  SCANNER_COMMAND+=" -Dsonar.exclusions=**/__pycache__/**,**/*.pyc,**/venv/**,**/.venv/**"
fi

# If nothing specific was detected, use generic configuration
if ! has_file_pattern "package.json" && ! has_file_pattern "pom.xml" && ! has_file_pattern "build.gradle" && ! has_file_pattern "requirements.txt" && ! has_file_pattern "setup.py" && ! has_file_pattern "Pipfile"; then
  echo -e "${BLUE}No specific project type detected, using generic configuration${NC}"
  SCANNER_COMMAND+=" -Dsonar.sources=."
  SCANNER_COMMAND+=" -Dsonar.exclusions=**/node_modules/**,**/vendor/**,**/target/**,**/build/**,**/.git/**"
fi

# Add sourceEncoding parameter
SCANNER_COMMAND+=" -Dsonar.sourceEncoding=UTF-8"

# Check if SonarQube is running
echo -e "${BLUE}Checking if SonarQube is running...${NC}"
if ! curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; then
  echo -e "${BLUE}SonarQube is not running. Starting it now...${NC}"
  (cd "$SONARQUBE_PATH" && docker-compose up -d)
  
  echo -e "${BLUE}Waiting for SonarQube to start...${NC}"
  until curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; do
    echo -n "."
    sleep 5
  done
  echo ""
else
  echo -e "${GREEN}SonarQube is already running.${NC}"
fi

# Create docker-compose.scanner.yml file if it doesn't exist
if [ ! -f "docker-compose.scanner.yml" ]; then
  cat > "docker-compose.scanner.yml" << 'EOF'
version: '3'
services:
  sonar-scanner:
    image: sonarsource/sonar-scanner-cli:latest
    volumes:
      - ./:/usr/src
    working_dir: /usr/src
    environment:
      - SONAR_HOST_URL=http://host.docker.internal:9000
      - SONAR_LOGIN=admin
      - SONAR_PASSWORD=admin
    extra_hosts:
      - "host.docker.internal:host-gateway"
EOF
fi

# Run SonarScanner
echo -e "${BLUE}Running SonarScanner...${NC}"
echo -e "${BLUE}Command: $SCANNER_COMMAND${NC}"

docker-compose -f docker-compose.scanner.yml run --rm sonar-scanner bash -c "$SCANNER_COMMAND"

if [ $? -eq 0 ]; then
  echo -e "${GREEN}Analysis complete!${NC}"
  echo -e "View results at ${BLUE}http://localhost:9000/dashboard?id=$PROJECT_KEY${NC}"
else
  echo -e "${RED}Analysis failed!${NC}"
fi