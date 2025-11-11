# .NET CRUD API for Nomad

This is a simple .NET in-memory CRUD API designed to run as an executable in Nomad.

## Features

- In-memory CRUD operations for a simple Item model
- Minimal API design with .NET 8
- Health check endpoint
- System information endpoint
- Swagger UI for API documentation and testing

## Building the Application

```bash
# Build the application for Linux (since Nomad will run it on Linux)
dotnet publish -c Release

# The executable will be in the bin/Release/net8.0/linux-x64/publish directory
```

## Running Locally

```bash
# Set the port (optional, defaults to 5000)
export PORT=5000

# Run the application
dotnet run
```

## API Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check endpoint
- `GET /info` - System information
- `GET /api/items` - Get all items
- `GET /api/items/{id}` - Get item by ID
- `POST /api/items` - Create a new item
- `PUT /api/items/{id}` - Update an existing item
- `DELETE /api/items/{id}` - Delete an item

## Swagger UI

When running, Swagger UI is available at `/swagger` for interactive API documentation and testing.
