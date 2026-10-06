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

Stop the environment:

```bash
docker compose down
```

Delete the database volume and recreate the database from migrations:

```bash
docker compose down -v
```
The migrations service is expected to exit successfully after applying migrations.

Run it from the `docker/local` directory:

```bash
cd ordreflow-hosting/docker/local
cp .env.example .env
docker compose up --build
```

DB_HOST is postgres inside Compose because that is the PostgreSQL service name. Flox is not needed for this setup.