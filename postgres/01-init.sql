CREATE USER keycloak_user WITH PASSWORD 'keycloak_pass';
CREATE USER yukinoise_user WITH PASSWORD 'yukinoise_pass';

CREATE DATABASE keycloak_db OWNER keycloak_user;
CREATE DATABASE yukinoise_db OWNER yukinoise_user;
