FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build

COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 \
    mvn dependency:go-offline --no-transfer-progress -q

COPY src ./src
RUN --mount=type=cache,target=/root/.m2 \
    mvn package -DskipTests --no-transfer-progress -q

FROM eclipse-temurin:21-jre
WORKDIR /deployments

COPY --from=builder /build/target/quarkus-app/lib/     ./lib/
COPY --from=builder /build/target/quarkus-app/*.jar    ./
COPY --from=builder /build/target/quarkus-app/app/     ./app/
COPY --from=builder /build/target/quarkus-app/quarkus/ ./quarkus/

ENV GC_TYPE=g1gc
ENV HEAP_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0"
ENV JAVA_OPTS=""

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "\
  if [ \"$GC_TYPE\" = 'zgc' ]; then \
    GC_FLAG='-XX:+UseZGC -XX:+ZGenerational'; \
  else \
    GC_FLAG='-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:G1HeapRegionSize=4m -XX:ParallelGCThreads=2'; \
  fi; \
  exec java $HEAP_OPTS $GC_FLAG $JAVA_OPTS -jar quarkus-run.jar"]