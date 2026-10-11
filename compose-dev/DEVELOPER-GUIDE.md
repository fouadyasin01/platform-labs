# Developer Guide

## Prerequisites

- Docker

## Environment Configuration

The Compose stack uses environment variables for PostgreSQL configuration.

Create your local `.env` file from the provided example:

```bash
cp .env.example .env
```

The `.env` file contains local configuration and is ignored by Git. Do not commit `.env`.

The provided `.env.example` contains:

```env
POSTGRES_DB=appdb
POSTGRES_USER=appuser
POSTGRES_PASSWORD=change-me
```

Update the values in `.env` if needed before starting the environment.

## Start the Development Environment

```bash
docker compose up -d
```

Check status:

```bash
docker compose ps
```

Services:

- React frontend
- Node.js API
- PostgreSQL database
- Redis cache

## Access the Application

Frontend:

```text
http://localhost:3000
```

API:

```text
http://localhost:8080
```

Health check:

```bash
curl http://localhost:8080/api/health
```

PostgreSQL test:

```bash
curl http://localhost:8080/api/users
```

Redis test:

```bash
curl http://localhost:8080/api/redis
```

## View Logs

API:

```bash
docker compose logs -f api
```

Frontend:

```bash
docker compose logs -f frontend
```

PostgreSQL:

```bash
docker compose logs -f db
```

Redis:

```bash
docker compose logs -f redis
```

All services:

```bash
docker compose logs -f
```

## Run Tests

```bash
docker compose exec api npm test
```

## Development and Hot Reloading

The development override bind-mounts the frontend and API source code into the containers, so source changes are available without rebuilding the images.

Debugging ports:

- Frontend: `9229`
- API: `9230`

## Database Persistence

PostgreSQL uses the named Docker volume `postgres-data`.

To completely reset the database:

```bash
docker compose down -v
docker compose up -d
```

> Warning: `docker compose down -v` deletes the PostgreSQL volume and all stored data.

The initial database schema and sample data are defined in:

```text
db/init.sql
```

The initialization script runs when the PostgreSQL data volume is created for the first time.

## Rebuild the Images

```bash
docker compose up -d --build
```

## Troubleshooting

Check container status:

```bash
docker compose ps -a
```

Check API logs:

```bash
docker compose logs --tail=50 api
```

Check PostgreSQL logs:

```bash
docker compose logs --tail=50 db
```

Check Redis logs:

```bash
docker compose logs --tail=50 redis
```

Check frontend logs:

```bash
docker compose logs --tail=50 frontend
```

Restart services:

```bash
docker compose restart api
docker compose restart frontend
```

Full environment reset:

```bash
docker compose down -v
docker compose up -d --build
```
