# Demo 03 — AppCDS Startup: Spring Boot 4.0.5 / Java 21

Demonstrates the 3-step manual AppCDS process for Spring Boot, contrasted
with Quarkus's single-property approach in `../quarkus-demo-03-appcds/`.

## Spring Boot AppCDS: 3 Steps

```bash
# Step 1: Dump class list
java -XX:DumpLoadedClassList=app.classlist -jar app.jar

# Step 2: Generate CDS archive
java -Xshare:dump \
     -XX:SharedClassListFile=app.classlist \
     -XX:SharedArchiveFile=app.jsa \
     -jar app.jar

# Step 3: Run with archive
java -Xshare:on -XX:SharedArchiveFile=app.jsa -jar app.jar
```

## Quarkus AppCDS: 1 Property

```properties
quarkus.package.jar.appcds.enabled=true
```

Maven plugin handles all three steps automatically.

## Expected Results

| | Baseline | AppCDS | Saving |
|--|---------|--------|--------|
| Spring Boot 4.0.5 | ~4000-6000 ms | ~2400-3600 ms | ~35-43% |

## Running

```bash
chmod +x demo.sh && ./demo.sh
```
