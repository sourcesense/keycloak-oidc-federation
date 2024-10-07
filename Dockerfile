FROM maven:3.8.5-openjdk-17 AS module-builder

WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn package -DskipTests

FROM quay.io/keycloak/keycloak:25.0.6 AS builder

# Enable health and metrics support
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Configure a database vendor
ENV KC_DB=postgres

WORKDIR /opt/keycloak
# for demonstration purposes only, please make sure to use proper certificates in production instead
RUN keytool -genkeypair -storepass password -storetype PKCS12 -keyalg RSA -keysize 2048 -dname "CN=server" -alias server -ext "SAN:c=DNS:localhost,IP:127.0.0.1" -keystore conf/server.keystore

# Copy the built JAR from the module-builder stage
COPY --from=module-builder /app/target/keycloak-oidc-federation-25.0.6.jar /opt/keycloak/providers/

USER root
RUN chown keycloak:keycloak /opt/keycloak/providers/keycloak-oidc-federation-25.0.6.jar \
    && chmod 644 /opt/keycloak/providers/keycloak-oidc-federation-25.0.6.jar
USER keycloak
ENV KC_SPI=all
# Build the optimized Keycloak server
RUN /opt/keycloak/bin/kc.sh build
FROM quay.io/keycloak/keycloak:25.0.6
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# Change these values to point to a running postgres instance
ENV KC_DB=postgres
ENV KC_DB_URL=jdbc:postgresql://postgres/keycloak
ENV KC_DB_USERNAME=keycloak
ENV KC_DB_PASSWORD=password
ENV KC_HOSTNAME=localhost
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]