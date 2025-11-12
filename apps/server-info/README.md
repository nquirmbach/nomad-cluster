# Server Environment Info App

A simple Flask web application that displays information about the hosting environment.

## Features

- Displays host information (hostname, IP address)
- Shows OS details and Python version
- Lists CPU and memory information
- Displays environment variables (excluding sensitive ones)
- Shows current server time

## Using Taskfile

This project includes a Taskfile.yml for easy management. Make sure you have [Task](https://taskfile.dev/) installed.

### Available Tasks

```bash
# List all available tasks
task

# Build the Docker image
task build

# Run the containerized application
task run

# Stop the running container
task stop

# View container logs
task logs

# Clean up Docker resources
task clean

# Run locally for development
task dev
```

## Running Locally

### Prerequisites

- Python 3.6+
- pip

### Installation

1. Install the required packages:

```bash
pip install -r requirements.txt
```

2. Run the application:

```bash
python app.py
```

3. Open your browser and navigate to http://localhost:8080

## Docker Deployment

### Building the Docker Image

```bash
docker build -t server-info-app .
```

### Running the Docker Container

```bash
docker run -p 8080:8080 server-info-app
```

Access the application at http://localhost:8080

## Environment Variables

You can add custom environment variables that will be displayed in the app:

```bash
docker run -p 8080:8080 -e "CUSTOM_VAR=my_value" server-info-app
```
