# Yukinoise Infrastructure

Development infrastructure for Yukinoise project with Docker Compose orchestration.

## Services

### Keycloak (Authentication & Authorization)
- **URL**: http://localhost/auth
- **Admin Console**: http://localhost/auth/admin
- **Default Admin User**: `admin` / `admin` (configured via `KC_ADMIN_USER`, `KC_ADMIN_PASS` env vars)
- **Health Check**: http://localhost:9000/health/ready (management port)
- **Database**: PostgreSQL (keycloak_db)

### PostgreSQL (Database)
- **Host**: localhost
- **Port**: 5432
- **Superuser**: `postgres` / `postgres`
- **Health Check**: Built-in healthcheck (pg_isready)

### Keycloak Databases
- **Database**: `keycloak_db`
  - **User**: `keycloak_user` / `keycloak_pass`
  - **Owner**: keycloak_user
- **Database**: `yukinoise_db`
  - **User**: `yukinoise_user` / `yukinoise_pass`
  - **Owner**: yukinoise_user

### Nginx (Reverse Proxy)
- **URL**: http://localhost
- **Routes**:
  - `/auth/*` → Keycloak (port 8080)
  - `/minio/*` → MinIO Console (port 9001)
  - `/*` → MinIO API / S3 (port 9000)

### MinIO (S3 Compatible Storage)
- **API Endpoint**: http://localhost:9000
- **Web Console**: http://localhost/minio/
- **Default Access Key**: `minio` / `minio12345`
- **Health Endpoint**: http://localhost:9000/minio/health/live

### Redis (Cache & Session Store)
- **Host**: localhost
- **Port**: 6379
- **Health Check**: redis-cli ping

### RabbitMQ (Message Broker)
- **AMQP Port**: 5672
- **Management UI**: http://localhost:15672
- **Default User**: `guest` / `guest`

## Environment Variables

Create a `.env` file in the root directory:

```bash
# PostgreSQL
PG_SUPERUSER=postgres
PG_SUPERPASS=postgres

# Keycloak
KC_DB_NAME=keycloak_db
KC_DB_USER=keycloak_user
KC_DB_PASS=keycloak_pass
KC_ADMIN_USER=admin
KC_ADMIN_PASS=admin

# MinIO
MINIO_USER=minio
MINIO_PASS=minio12345

# RabbitMQ
RABBIT_USER=guest
RABBIT_PASS=guest
```

## Keycloak Realm Configuration

### Realm: `yukinoise`
- **Status**: Enabled
- **Features**:
  - User registration enabled
  - Email verification required
  - Brute force protection enabled
  - Access token lifetime: 600 seconds (10 minutes)

### Clients

#### Public Client: `yukinoise-desktop`
- **Type**: OIDC / Authorization Code + PKCE
- **Redirect URIs**:
  - `http://127.0.0.1:*`
  - `http://localhost:*`
  - `yukinoise://callback`
- **Web Origins**: `http://127.0.0.1`, `http://localhost`
- **PKCE**: S256
- **Protocol Mappers**:
  - `audience-yukinoise-api`: Maps `yukinoise-api` to `aud` claim
  - `groups`: Full group paths to `groups` claim
  - `profile_id`: User attribute to `profile_id` claim
- **Built-in Scopes**: profile, email, roles, web-origins, acr

#### Resource Server: `yukinoise-api`
- **Type**: Bearer token validation only
- **Purpose**: API audience definition (cannot be used for login)

#### Service Clients (for backend services)
- `svc-releases`
- `svc-music`
- `svc-social`
- `svc-discovery`
- `svc-notifications`

**Configuration**:
- **Flow**: Client Credentials (service account)
- **Service Accounts**: Enabled
- **Direct Access Grants**: Disabled
- **Standard Flow**: Disabled
- **Authentication**: Client Secret (Basic)
- **Secrets**: Managed by Keycloak (not committed to repository)

### Realm Roles
- `user` (default for all users)
- `admin`
- `moderator`
- `service` (for service accounts)
- `offline_access` (UMA)
- `uma_authorization` (UMA)

### Groups
- `/admins` → Realm role: `admin`
- `/moderators` → Realm role: `moderator`

## Starting Services

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f keycloak

# Stop all services
docker compose down

# Stop and remove volumes (WARNING: deletes data)
docker compose down -v
```

## Health Checks

All services include healthchecks that can be monitored:

```bash
# Check service status
docker compose ps

# View healthcheck details
docker inspect yukinoise-keycloak | grep -A 5 '"Health"'
```

## Token Flow

### Desktop Client (Authorization Code + PKCE)

```
1. Desktop app initiates auth flow:
   GET http://localhost/auth/realms/yukinoise/protocol/openid-connect/auth?
       client_id=yukinoise-desktop
       scope=openid profile email roles groups
       response_type=code
       redirect_uri=yukinoise://callback
       code_challenge=<S256_hash>
       code_challenge_method=S256

2. User authenticates and consents

3. Keycloak redirects to callback with authorization code
   yukinoise://callback?code=<auth_code>&session_state=...

4. Desktop exchanges code for tokens:
   POST http://localhost/auth/realms/yukinoise/protocol/openid-connect/token
   code=<auth_code>
   client_id=yukinoise-desktop
   grant_type=authorization_code
   code_verifier=<PKCE_verifier>

5. Response includes access_token with:
   - sub: user ID
   - preferred_username
   - email
   - email_verified
   - realm_access.roles: [user, admin, ...]
   - groups: [/admins, /moderators, ...]
   - aud: [yukinoise-api]
   - profile_id: <user_profile_id> (if set)
```

### Service Client (Client Credentials)

```
1. Service requests token:
   POST http://localhost/auth/realms/yukinoise/protocol/openid-connect/token
   client_id=svc-releases
   client_secret=<secret_from_keycloak>
   grant_type=client_credentials

2. Response includes service account token with access_token containing:
   - sub: service account ID
   - realm_access.roles: [service, ...]
   - client_id: svc-releases
```

## Security Notes

⚠️ **Development Only**: Default credentials (admin/admin, minio/minio12345, etc.) are for development use only.

- **Secrets**: Service client secrets are generated by Keycloak and stored internally. Never commit real secrets to repository.
- **Environment Variables**: Use `.env` file for configuration (add to `.gitignore`)
- **HTTPS**: Configure proper SSL/TLS for production deployments
- **Network**: All services communicate via internal Docker network `yuki`

## Troubleshooting

### Keycloak won't start
- Check PostgreSQL is healthy: `docker compose logs postgres`
- Verify Keycloak health: `docker compose logs keycloak | grep -i error`
- Ensure realm JSON is valid: `python3 -m json.tool keycloak/import/realm-yukinoise.json`

### Cannot reach services
- Verify nginx is running: `docker compose ps nginx`
- Check nginx logs: `docker compose logs nginx`
- Test connectivity: `curl http://localhost/auth/`

### Port conflicts
- Change host ports in `docker-compose.yml` if 5432, 6379, 5672, 9000, 9001, or 80 are in use
- Example: Change `"5432:5432"` to `"5433:5432"` for PostgreSQL

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak Admin REST API](https://www.keycloak.org/docs-api)
- [OIDC/OAuth2 Standards](https://openid.net/specs/openid-connect-core-1_0.html)