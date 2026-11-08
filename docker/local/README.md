# Local Docker Compose

From `docker/local`, copy the environment file and replace the `JWT_SECRET` placeholder with a random secret (for example, generate one with `openssl rand -base64 48`):

```bash
cp .env.example .env
```

Have these images available in your local Docker image store: `ordreflow-migrations:local`, `ordreflow-api:local`, and `ordreflow-frontend:local`. Compose pulls `postgres:17-alpine` automatically when needed.

Make sure `ordreflow-api:local` is the **backend runtime** image, not the Nginx frontend image. Check its entrypoint with:

```bash
docker image inspect ordreflow-api:local --format '{{json .Config.Entrypoint}}'
```

It should run `dotnet WebApi.dll`. If it instead shows `/docker-entrypoint.sh`, tag the correct API image as `ordreflow-api:local` and recreate the API and frontend with `docker compose up -d --no-deps --force-recreate api frontend` (after the database, migrations, and seed have started).

Start PostgreSQL, run migrations, load demo data, and start the API and frontend:

```bash
docker compose up
```

The frontend is at http://localhost:8081 and the API Swagger UI is at http://localhost:8080/swagger. Change `FRONTEND_PORT` or `API_PORT` in `.env` if those host ports are in use. PostgreSQL is exposed on `DB_PORT` (default 5432) for local development; containers reach it at `postgres:5432`.

`migrations` and `seed` exit successfully before the API starts. The seed service runs `seed-demo.sql` automatically. On an empty migrated database it adds 30 demo users, 12 orders, 50 tasks, 246 time entries, and 220 reviews, including entries across several weeks and different review statuses. It also creates Identity login accounts for the demo users. Running it again does not duplicate rows or overwrite edits.

Use these local demo logins (the API's `ADMIN_*` bootstrap account is separate):

| Role | Email | Password |
| --- | --- | --- |
| Admin | `alex.admin@example.com` | `DemoAdmin123!` |
| Manager | `morgan.manager@example.com`, `sam.manager@example.com`, `demo.manager01@example.com` through `demo.manager02@example.com` | `DemoManager123!` |
| Employee | `casey.employee@example.com`, `jordan.employee@example.com`, `taylor.employee@example.com`, `demo.employee01@example.com` through `demo.employee21@example.com` | `DemoEmployee123!` |

`robin.inactive@example.com` also has the employee password, but login is rejected because that user is inactive.

Stop the environment:

```bash
docker compose down
```

To reset the database (deleting all database data), remove the volume and start Compose again. Migrations and demo seeding run automatically:

```bash
docker compose down -v
docker compose up
```

Flox is not needed for this setup.
