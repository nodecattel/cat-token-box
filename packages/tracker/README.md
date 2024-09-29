# CAT Tracker

The CAT Tracker is a tool that reads CAT token transactions from the blockchain, stores them in PostgreSQL in a structured way, and provides quick access to this data via RESTful APIs.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Running the Services](#running-the-services)
5. [Accessing the API](#accessing-the-api)
6. [Performance Optimization](#performance-optimization)
7. [Troubleshooting](#troubleshooting)
8. [Updating](#updating)
9. [Support](#support)

## Prerequisites

Before you begin, ensure you have the following installed:
- Node.js (v14 or later)
- Yarn package manager
- Docker and Docker Compose
- Git

## Installation

1. Navigate to the tracker directory:
   ```bash
   cd ~/cat-token-box/packages/tracker
   ```

2. Install dependencies and build the project:
   ```bash
   yarn install && yarn build
   ```

3. Set up the environment:
   - Copy the `.env.example` file to `.env`:
     ```bash
     cp .env.example .env
     ```
   - Open `.env` and update the configuration variables as needed (see [Configuration](#configuration) section).

4. Update directory permissions:
   ```bash
   sudo chmod o+w docker/data
   ```

## Configuration

The `.env` file contains important configuration settings. Key variables include:

- `API_PORT`: Port number for the API server (default: 3000)
- `GENESIS_BLOCK_HEIGHT`: Starting block height for syncing (default: 0)
- `WORKER_PORT`: Port number for the worker process (default: 3001)
- `WORKER_CONCURRENCY`: Number of concurrent worker processes (default: 4)
- `BATCH_SIZE`: Number of transactions to process in a batch (default: 1000)
- `SYNC_INTERVAL`: Interval (in milliseconds) between sync attempts (default: 10000)
- `TYPEORM_CONNECTION_LIMIT`: Maximum number of database connections (default: 100)
- `TYPEORM_QUERY_TIMEOUT`: Timeout (in milliseconds) for database queries (default: 60000)

### Docker User Configuration

The `.env` file includes `UID` and `GID` variables. These should be set to match your host system's user ID and group ID. To find your UID and GID, run:

```bash
id -u && id -g
```

Then, update the `UID` and `GID` values in your `.env` file with the numbers returned by this command.

## Running the Services

1. Start PostgreSQL and Bitcoin node:
   ```bash
   docker-compose up -d
   ```

2. Initialize/migrate the database:
   ```bash
   yarn migration:run
   ```
   **Note:** If upgrading from a previous version, this may take several hours. Always backup your database before migrating.

3. Start the tracker worker:
   ```bash
   # For development
   yarn start:worker

   # For production with enhanced performance
   yarn start:worker:prod:plus
   ```

4. Start the API server (in another terminal):
   ```bash
   # For development
   yarn start:api

   # For production
   yarn start:api:prod
   ```

## Accessing the API

Once the services are running:
- The API documentation (Swagger) can be accessed at: http://127.0.0.1:3000
- The sync-up progress can be checked at: http://127.0.0.1:3000/api

**Important:** Ensure the tracker has synced to the latest block before running any commands or queries against it.

## Performance Optimization

To optimize the performance of the CAT Tracker, you can adjust the following variables in your `.env` file:

1. Increase `WORKER_CONCURRENCY` to utilize more CPU cores.
2. Adjust `BATCH_SIZE` based on your system's memory.
3. Decrease `SYNC_INTERVAL` to sync more frequently, or increase it to reduce database load.
4. Increase `TYPEORM_CONNECTION_LIMIT` for more concurrent database connections.
5. Adjust `TYPEORM_QUERY_TIMEOUT` based on your network latency and query complexity.

Example optimization for a high-performance system:

```
WORKER_CONCURRENCY=8
BATCH_SIZE=5000
SYNC_INTERVAL=5000
TYPEORM_CONNECTION_LIMIT=200
TYPEORM_QUERY_TIMEOUT=120000
```

After modifying these variables, restart the worker process for the changes to take effect:

```bash
yarn start:worker:prod:plus
```

Monitor system resources and adjust these values iteratively to find the optimal configuration for your hardware and network conditions.

## Troubleshooting

- If you encounter permission issues with Docker volumes:
  ```bash
  sudo chown -R $(id -u):$(id -g) docker/data docker/pgdata
  ```

- If services fail to start, check the Docker logs:
  ```bash
  docker-compose logs
  ```

- For database-related issues, connect to PostgreSQL directly:
  ```bash
  docker-compose exec postgres psql -U your_username -d your_database
  ```

## Updating

When updating the tracker:

1. Pull the latest changes:
   ```bash
   git pull origin main
   ```

2. Rebuild the project:
   ```bash
   yarn install && yarn build
   ```

3. Run database migrations:
   ```bash
   yarn migration:run
   ```

4. Restart the services as described in the [Running the Services](#running-the-services) section.

## Support

For issues, questions, or contributions, please open an issue in the GitHub repository or contact the maintainer at support@example.com.
