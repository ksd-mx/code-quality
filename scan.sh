#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default project key and name from directory name
DEFAULT_PROJECT_KEY=$(basename $(pwd) | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
DEFAULT_PROJECT_NAME=$(basename $(pwd))

# Define repo URL
REPO_URL="https://raw.githubusercontent.com/ksd-mx/code-quality/main"

# Parse command line options
PROJECT_KEY=$DEFAULT_PROJECT_KEY
PROJECT_NAME=$DEFAULT_PROJECT_NAME
USE_ADMIN=false

print_usage() {
  echo "Usage: ./scan.sh [options]"
  echo ""
  echo "Options:"
  echo "  -k, --key KEY         Project key (default: directory name)"
  echo "  -n, --name NAME       Project name (default: directory name)"
  echo "  --admin               Force using admin credentials instead of token"
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
    --admin)
      USE_ADMIN=true
      shift
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

# Function to check if SonarQube is running
check_sonarqube_running() {
  echo -e "${BLUE}Checking if SonarQube is running...${NC}"
  if curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; then
    return 0  # Running
  else
    return 1  # Not running
  fi
}

# Function to wait for SonarQube to be ready
wait_for_sonarqube() {
  echo -e "${BLUE}Waiting for SonarQube to initialize (this may take a minute)...${NC}"
  local max_attempts=60
  local attempt=0
  
  while ! curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"'; do
    attempt=$((attempt+1))
    if [ $attempt -ge $max_attempts ]; then
      echo -e "${RED}Timeout waiting for SonarQube to start.${NC}"
      exit 1
    fi
    echo -n "."
    sleep 5
  done
  echo ""
  
  # Give it a bit more time to fully initialize
  sleep 10
  
  echo -e "${GREEN}SonarQube server is now running at http://localhost:9000${NC}"
}

# Function to start or set up SonarQube
setup_sonarqube() {
  # First check if Docker is installed
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker first.${NC}"
    echo -e "${YELLOW}Visit https://docs.docker.com/get-docker/ for installation instructions.${NC}"
    exit 1
  fi

  # Check if docker-compose is installed
  if ! command -v docker-compose >/dev/null 2>&1; then
    echo -e "${RED}Error: docker-compose is not installed. Please install docker-compose first.${NC}"
    echo -e "${YELLOW}Visit https://docs.docker.com/compose/install/ for installation instructions.${NC}"
    exit 1
  fi

  # Create local SonarQube server with all files if not already set up
  SONARQUBE_HOME="$HOME/.sonarqube"
  
  # Create SonarQube directory if it doesn't exist
  if [ ! -d "$SONARQUBE_HOME" ]; then
    echo -e "${BLUE}Creating SonarQube directory at $SONARQUBE_HOME...${NC}"
    mkdir -p "$SONARQUBE_HOME"
  fi
  
  # Download docker-compose.yaml if it doesn't exist
  if [ ! -f "$SONARQUBE_HOME/docker-compose.yaml" ]; then
    echo -e "${BLUE}Downloading docker-compose.yaml for SonarQube server...${NC}"
    curl -s -o "$SONARQUBE_HOME/docker-compose.yaml" "$REPO_URL/docker-compose.yaml"
  fi
  
  # Download setup-token.sh if it doesn't exist
  if [ ! -f "$SONARQUBE_HOME/setup-token.sh" ]; then
    echo -e "${BLUE}Downloading setup-token.sh script...${NC}"
    curl -s -o "$SONARQUBE_HOME/setup-token.sh" "$REPO_URL/setup-token.sh"
    chmod +x "$SONARQUBE_HOME/setup-token.sh"
  fi
  
  # Start SonarQube if it's not running
  if ! check_sonarqube_running; then
    echo -e "${YELLOW}SonarQube is not running. Starting it now...${NC}"
    (cd "$SONARQUBE_HOME" && docker-compose up -d)
    
    wait_for_sonarqube
    
    # Make sure admin password is set to admin (in case it asks to change)
    curl -X POST -u admin:admin "http://localhost:9000/api/users/change_password" \
      -d "login=admin&previousPassword=admin&password=admin" > /dev/null 2>&1
      
    echo -e "${GREEN}Default login: admin/admin${NC}"
  else
    echo -e "${GREEN}SonarQube is already running.${NC}"
  fi
}

# Function to create the scanner configuration file
create_scanner_config() {
  echo -e "${BLUE}Creating scanner configuration file...${NC}"
  cat > "docker-compose.scanner.yml" << EOL
services:
  sonar-scanner:
    image: sonarsource/sonar-scanner-cli:latest
    volumes:
      - ./:/usr/src
    working_dir: /usr/src
    environment:
      - SONAR_HOST_URL=http://host.docker.internal:9000
    extra_hosts:
      - "host.docker.internal:host-gateway"
EOL
  echo -e "${GREEN}Scanner configuration file created.${NC}"
}

# Detect project type and create appropriate parameters
detect_project_type() {
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
    echo -e "${YELLOW}No specific project type detected, using generic configuration${NC}"
    SCANNER_COMMAND+=" -Dsonar.sources=."
    SCANNER_COMMAND+=" -Dsonar.exclusions=**/node_modules/**,**/vendor/**,**/target/**,**/build/**,**/.git/**"
  fi

  # Add sourceEncoding parameter
  SCANNER_COMMAND+=" -Dsonar.sourceEncoding=UTF-8"
  
  # Add authentication parameters
  if [ "$USE_ADMIN" = true ]; then
    SCANNER_COMMAND+=" -Dsonar.login=admin -Dsonar.password=admin"
  fi
}

# Main script execution
echo -e "${BLUE}====== SonarQube Scanner ======${NC}"
echo -e "${BLUE}Project: ${GREEN}$PROJECT_NAME${NC}"

# Check for Docker and docker-compose
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}Error: Docker is not installed. Please install Docker first.${NC}"
  echo -e "${YELLOW}Visit https://docs.docker.com/get-docker/ for installation instructions.${NC}"
  exit 1
fi

if ! command -v docker-compose >/dev/null 2>&1; then
  echo -e "${RED}Error: docker-compose is not installed. Please install docker-compose first.${NC}"
  echo -e "${YELLOW}Visit https://docs.docker.com/compose/install/ for installation instructions.${NC}"
  exit 1
fi

# Setup and start SonarQube if needed
setup_sonarqube

# Create the scanner config file (without token)
create_scanner_config

# Detect project type
detect_project_type

# Run SonarScanner
echo -e "${BLUE}Running SonarScanner using admin credentials...${NC}"
echo -e "${BLUE}Command: $SCANNER_COMMAND${NC}"

# Run with admin credentials
docker-compose -f docker-compose.scanner.yml run -e SONAR_LOGIN=admin -e SONAR_PASSWORD=admin --rm sonar-scanner bash -c "$SCANNER_COMMAND"
SCAN_RESULT=$?

if [ $SCAN_RESULT -eq 0 ]; then
  echo -e "${GREEN}Analysis complete!${NC}"
  echo -e "View results at ${BLUE}http://localhost:9000/dashboard?id=$PROJECT_KEY${NC}"
else
  echo -e "${RED}Analysis failed!${NC}"
  
  # Provide detailed diagnostics
  echo -e "${YELLOW}Detailed diagnostics:${NC}"
  echo -e "1. Checking SonarQube status..."
  curl -s http://localhost:9000/api/system/status
  echo -e "\n2. Testing admin authentication..."
  if curl -s -u admin:admin "http://localhost:9000/api/system/status" | grep -q '"status":"UP"'; then
    echo -e "${GREEN}Admin authentication works!${NC}"
  else
    echo -e "${RED}Admin authentication failed!${NC}"
  fi
  
  echo -e "\n${YELLOW}Troubleshooting tips:${NC}"
  echo -e "1. Make sure SonarQube server is running at http://localhost:9000"
  echo -e "2. Check if Docker has permission to access your project directory"
  echo -e "3. Try logging in to SonarQube UI (admin/admin) and verify it's working"
  echo -e "4. Check SonarQube logs: docker logs \$(docker ps | grep sonarqube | awk '{print \$1}')"
fi