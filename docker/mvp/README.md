# Local MVP stack

This stack pulls the public `ghcr.io/ordreflow/ordreflow-api:mvp`, `ghcr.io/ordreflow/ordreflow-frontend:mvp`, and `ghcr.io/ordreflow/ordreflow-migrations:mvp` images. It uses its own Compose project and database volume, separate from `docker/local`. No image builds or cloud deployment setup are needed.

The included `.env` has ready-to-use local test settings. From the repository root:

```bash
cd docker/mvp
docker compose pull
docker compose up -d --wait
docker compose ps -a
```

When `docker compose up -d --wait` finishes, open the frontend at **http://localhost:18089**. Its health check verifies that the frontend can proxy requests to the API. You can check it yourself with `curl -fsS http://localhost:18089/api/health`. The API health endpoint is also available directly at http://localhost:18088/api/health.

To open the frontend on a phone connected to the same Wi-Fi, use **http://YOUR_COMPUTER_LAN_IP:18089**. On Linux, run `hostname -I` and choose the address on the same network as your phone. On Windows, run `ipconfig` in PowerShell or Command Prompt and use the **IPv4 Address** under your Wi-Fi adapter (not a WSL or virtual adapter). No router port forwarding is needed. If the phone cannot connect, check that your computer's firewall permits incoming TCP on port `18089` and that the Wi-Fi does not isolate connected devices. `docker compose port frontend 8080` shows the published port; `0.0.0.0` in its output means the frontend is listening on all host interfaces, not an address to enter on the phone.

PostgreSQL starts first, then the migrations and demo seed finish before the API starts. The seed uses the shared [`docker/local/seed-demo.sql`](../local/seed-demo.sql). Demo logins are listed in [`docker/local/README.md`](../local/README.md).

The host ports (`DB_PORT=15439`, `API_PORT=18088`, `FRONTEND_PORT=18089`) avoid common database and web server defaults. PostgreSQL and the API bind only to localhost; only the frontend is accessible on the LAN. Change the ports in `.env` if needed; `.env.example` provides a template for different credentials or ports.

Stop this stack with `docker compose down`. To delete **only the MVP database** and start it again from scratch, run `docker compose down -v` followed by `docker compose up -d --wait`.
