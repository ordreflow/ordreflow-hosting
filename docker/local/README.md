Copy the environment file:

```bash
cp .env.example .env
```

to use docker compose you need to have the images in your local docker repository:
```
ordreflow-migrations:local
ordreflow-api:local
ordreflow-frontend:local
```
docker will pull a postgres image from cloud automatically

Start PostgreSQL, run migrations, and start the API:

```bash
docker compose up --build
```

The API is available at:

```
http://localhost:8080/swagger
```

To add optional demo data after the migrations service exits successfully, keep Compose running and run this from `docker/local` in another terminal:

```bash
docker compose exec -T postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < seed-demo.sql
```

`seed-demo.sql` is optional and is not run automatically. On an empty migrated database it adds 30 demo users, 12 orders, 50 tasks, 246 time entries, and 220 reviews, including entries across several weeks and different review statuses. It also creates Identity login accounts for the demo users. Running it again does not duplicate rows or overwrite edits.

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

To start with an empty database, delete the database volume (this removes all database data), then start Compose again. Run the seed command above again if you want demo data:

```bash
docker compose down -v
docker compose up --build
```

The migrations service is expected to exit successfully after applying migrations.

Run it from the `docker/local` directory:

```bash
cd ordreflow-hosting/docker/local
cp .env.example .env
docker compose up --build
```

DB_HOST is postgres inside Compose because that is the PostgreSQL service name. Flox is not needed for this setup.
