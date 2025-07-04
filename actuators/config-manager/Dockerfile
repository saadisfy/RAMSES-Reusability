# Build stage
FROM eclipse-temurin:17-jdk AS builder
WORKDIR /app
COPY . .
RUN ./gradlew :config-manager:build -x test

# Runtime stage
FROM eclipse-temurin:17-jre@sha256:408521f62c9a7589b3960addc4e21552ca0f47bfb8653bdc0a7de3648021d6d9
RUN mkdir /app
WORKDIR /app
COPY --from=builder /app/config-manager/build/libs/*-latest.jar ./spring-boot-application.jar
ENTRYPOINT ["java","-jar","/app/spring-boot-application.jar"]
EXPOSE 58016