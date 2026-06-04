# Stage 1: Build the application
FROM maven:3.9.6-eclipse-temurin-17-alpine AS builder
WORKDIR /app

# Copy files and build the package
COPY pom.xml .
COPY src ./src
RUN mvn clean package -B -ntp -DskipTests -Dmaven.wagon.http.retryHandler.count=5 -Dmaven.wagon.http.retryHandler.requestSentRetryEnabled=true

# Stage 2: Create the production runtime image
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Create a non-root group and user for security
RUN addgroup -S spring && adduser -S spring -G spring

# Copy the built jar file from the builder stage
COPY --from=builder /app/target/*.jar app.jar

# Change ownership of the app directory to the spring user
RUN chown -R spring:spring /app

# Run as the spring user
USER spring:spring

# Expose the notification service port
EXPOSE 8040

# Production JVM options (G1 garbage collector, exit on OOM, container memory limits)
ENV JAVA_OPTS="-XX:+UseG1GC -XX:+ExitOnOutOfMemoryError -XX:MaxRAMPercentage=75.0"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
