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

`seed-demo.sql` inserts sample users, orders, tasks, time entries, and reviews. It is not run automatically. You can run it again without duplicating the sample rows or overwriting edits to them.

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
