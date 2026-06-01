# ==========================================
# STAGE 1: Build the application
# ==========================================
FROM eclipse-temurin:25-jdk AS builder

WORKDIR /app

# Copy the Maven wrapper and pom.xml first
# (This allows Docker to cache your downloaded dependencies)
COPY .mvn/ .mvn
COPY mvnw pom.xml ./

# Ensure the Maven wrapper has execution permissions
RUN chmod +x mvnw

# Download dependencies before copying the source code
RUN ./mvnw dependency:go-offline

# Copy the actual source code
COPY src ./src

# Build the final .jar file (skipping tests to speed up the build)
RUN ./mvnw clean package -DskipTests

# ==========================================
# STAGE 2: Create the lightweight runtime image
# ==========================================
FROM eclipse-temurin:25-jre

WORKDIR /app

# Copy ONLY the built .jar file from the 'builder' stage above
COPY --from=builder /app/target/*.jar app.jar

# Expose the standard Spring Boot port
EXPOSE 8080

# Command to run the application
ENTRYPOINT ["java", "-jar", "app.jar"]