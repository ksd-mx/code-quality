# Zero-Config SonarQube Local Scanner

Just copy one file and run one command to analyze any project with SonarQube. No manual setup, no tokens, no bullshit.

## One-Minute Setup

1. **Copy the script to your project:**
   ```bash
   curl -o scan.sh https://raw.githubusercontent.com/ksd-mx/code-quality/main/scan.sh
   chmod +x scan.sh
   ```

2. **Run it:**
   ```bash
   ./scan.sh
   ```

That's it! The script will:
- Set up a SonarQube server automatically if one doesn't exist
- Detect what type of project you have (Java, Node.js, Python, etc.)
- Run the appropriate analysis
- Show you the results

## Repository Structure

- `scan.sh` - The main script you need to run in your projects
- `docker-compose.yaml` - SonarQube server configuration
- `docker-compose.scanner.yml` - Scanner configuration template
- `setup-token.sh` - Automatic token setup script (used internally)

## How It Works

The `scan.sh` script handles everything:

- **First-time setup:** Creates and starts a SonarQube server if needed
- **Auto-detection:** Identifies your project type and configures the scanner
- **Zero configuration:** No tokens, no manual steps, no configuration files
- **Docker-based:** Everything runs in containers - no local installation needed

## Options

You rarely need these, but they're available:

```bash
./scan.sh --name "My Project" --key my-custom-key
```

- `--name` or `-n`: Custom project name in SonarQube
- `--key` or `-k`: Custom project key in SonarQube

## Team Usage

1. Include the `scan.sh` file in your repo
2. Add this to your README:
   ```
   ## Code Quality
   Run `./scan.sh` before committing to check code quality with SonarQube
   ```

Everyone on the team can now use the same simple command to analyze code locally.

## What's Detected Automatically

- **JavaScript/Node.js:** package.json
- **TypeScript:** tsconfig.json
- **Java Maven:** pom.xml
- **Java Gradle:** build.gradle
- **Python:** requirements.txt, setup.py, Pipfile
- **Test coverage:** Jest, JaCoCo, Python coverage

The script also handles building Java projects automatically if needed.

## Notes

- SonarQube runs on http://localhost:9000 (login: admin/admin)
- All data is stored in Docker volumes for persistence

## Source

This tool is maintained at https://github.com/ksd-mx/code-quality

If you encounter any issues or have suggestions, please create an issue in the repository.