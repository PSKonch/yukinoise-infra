-- Databases
CREATE DATABASE keycloak_db;
CREATE DATABASE yukinoise_db;

-- Users
CREATE USER keycloak_user WITH PASSWORD 'keycloak_pass';
CREATE USER yukinoise_user WITH PASSWORD 'yukinoise_pass';

-- Privileges
GRANT ALL PRIVILEGES ON DATABASE keycloak_db TO keycloak_user;
GRANT ALL PRIVILEGES ON DATABASE yukinoise_db TO yukinoise_user;
