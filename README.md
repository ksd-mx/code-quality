# Zero-Config SonarQube Scanner

A super simple tool that lets you scan any code project with SonarQube using just one command. No manual setup, no fuss.

## What does this do?

This tool:
1. Sets up a local SonarQube server automatically
2. Detects what kind of project you have (Java, Node.js, Python, etc.)
3. Scans your code for bugs, security issues, and code smells
4. Shows you the results in a nice dashboard

All with a single command!

## Step-by-Step Instructions

### One-Time Setup (First Time Only)

If this is your first time using this tool, just run the following command in your project folder:

```bash
curl -o scan.sh https://raw.githubusercontent.com/ksd-mx/code-quality/main/scan.sh && chmod +x scan.sh && ./scan.sh
```

This will:
1. Download the scan script to your project folder
2. Make it executable
3. Run it, which will:
   - Create a SonarQube server in your home directory (under `~/.sonarqube`)
   - Start the server (this might take a minute or two the first time)
   - Scan your current project
   - Show you the results link

### For New Projects

After you've done the one-time setup, for each new project you want to scan:

```bash
curl -o scan.sh https://raw.githubusercontent.com/ksd-mx/code-quality/main/scan.sh && chmod +x scan.sh && ./scan.sh
```

Or, if you already have the script in another project, you can just copy it:

```bash
cp /path/to/existing/project/scan.sh . && chmod +x scan.sh && ./scan.sh
```

### Running Subsequent Scans

Once you have the `scan.sh` file in your project folder, you can run it anytime to scan your code:

```bash
./scan.sh
```

## Accessing SonarQube Dashboard

After running the scan, you can access the SonarQube dashboard at:

```
http://localhost:9000
```

**Default login credentials:**
- Username: `admin`
- Password: `admin`

Your project results will be available at:
```
http://localhost:9000/dashboard?id=your-project-key
```
(The link will be shown in the terminal after the scan completes)

## Troubleshooting

### Docker is not installed

If you see an error about Docker not being installed, you'll need to install Docker first:

1. Visit https://docs.docker.com/get-docker/
2. Follow the installation instructions for your operating system
3. Make sure Docker is running before trying again

### SonarQube server won't start

If SonarQube fails to start, try:

1. Make sure ports 9000 is available on your system
2. Increase Docker memory allocation in Docker Desktop settings
3. Restart Docker and try again

### Scan fails

If the scan itself fails:

1. Check if SonarQube is running by visiting http://localhost:9000 in your browser
2. Make sure your project has the right structure (e.g., for Java projects, make sure you've built the project first)
3. Try running with additional parameters (see "Options" below)

## Options

You can customize the scan with these options:

```bash
./scan.sh --name "My Project Name" --key custom-project-key
```

- `--name` or `-n`: Set a custom project name in SonarQube (default: directory name)
- `--key` or `-k`: Set a custom project key in SonarQube (default: directory name, with special characters replaced)

## Supported Project Types

The scanner automatically detects and configures:

- **JavaScript/TypeScript**: Detects package.json/tsconfig.json
- **Java**: Detects Maven (pom.xml) or Gradle (build.gradle) projects
- **Python**: Detects requirements.txt, setup.py, or Pipfile
- **Generic**: Falls back to a general configuration for other project types

## For Teams

Add this to your project onboarding instructions:

```markdown
## Code Quality

Run the SonarQube scanner before committing to check code quality:

1. Download and run the scanner in your project folder:
   ```bash
   curl -o scan.sh https://raw.githubusercontent.com/ksd-mx/code-quality/main/scan.sh && chmod +x scan.sh && ./scan.sh
   ```

2. Check the results at the URL shown in the output
3. Fix any issues before committing your code
```

## How It Works Behind the Scenes

1. The script first checks if SonarQube is installed and running
2. If not, it sets up SonarQube server in your home directory (`~/.sonarqube`)
3. It then detects your project type by looking for specific files
4. Based on the project type, it configures the appropriate SonarQube scanner
5. It runs the scanner in a Docker container to analyze your code
6. Finally, it provides a link to view the results

## Requirements

- Docker
- docker-compose
- curl (for downloading the script)
- Internet connection (for pulling Docker images the first time)

## Stopping SonarQube Server

If you want to stop the SonarQube server to free up resources:

```bash
cd ~/.sonarqube && docker-compose down
```

## Source & Support

This tool is maintained at [https://github.com/ksd-mx/code-quality](https://github.com/ksd-mx/code-quality)

If you encounter issues or have suggestions, please create an issue in the repository.