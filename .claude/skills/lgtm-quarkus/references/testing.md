# Testing Infrastructure

Multi-layer test strategy for Quarkus projects.

## Test layers

| Layer | Framework | Scope | Speed | Maven phase |
|---|---|---|---|---|
| 1. Unit tests | JUnit 5 + `camel-quarkus-junit5` (if Camel) or `@QuarkusTest` | Single class/route logic | Seconds | `test` (surefire) |
| 2. Integration tests | Citrus 4.x + Testcontainers | Cross-service flows, real infra | Minutes | `verify` (failsafe) |
| 3. API tests | Newman (Postman CLI) | HTTP contract validation | Seconds | Script or CI stage |

### Naming convention

- `*Test.java` — unit tests, run by surefire
- `*IT.java` — integration tests, run by failsafe

## Layer 1: Unit tests

### Maven dependencies

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit5</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>io.rest-assured</groupId>
    <artifactId>rest-assured</artifactId>
    <scope>test</scope>
</dependency>
```

### Pattern: REST endpoint test

```java
@QuarkusTest
class GreetingResourceTest {

    @Test
    void testHelloEndpoint() {
        given()
            .when().get("/hello")
            .then()
            .statusCode(200)
            .body(is("Hello"));
    }
}
```

### Pattern: Micrometer metric assertion

```java
@QuarkusTest
class MetricsTest {

    @Inject
    MeterRegistry registry;

    @Test
    void processedCounterIncrements() {
        // trigger processing...

        Counter counter = registry.find("app.processed.total")
            .tag("type", "widget")
            .counter();
        assertNotNull(counter);
        assertTrue(counter.count() > 0);
    }
}
```

## Layer 2: Citrus integration tests

### Maven dependencies

```xml
<dependency>
    <groupId>org.citrusframework</groupId>
    <artifactId>citrus-quarkus</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.citrusframework</groupId>
    <artifactId>citrus-http</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.citrusframework</groupId>
    <artifactId>citrus-validation-json</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.citrusframework</groupId>
    <artifactId>citrus-testcontainers</artifactId>
    <scope>test</scope>
</dependency>
```

Add to parent POM `dependencyManagement`:

```xml
<dependency>
    <groupId>org.citrusframework</groupId>
    <artifactId>citrus-bom</artifactId>
    <version>4.10.3</version>
    <type>pom</type>
    <scope>import</scope>
</dependency>
```

### Maven plugin config

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <configuration>
        <includes><include>**/*Test.java</include></includes>
        <excludes><exclude>**/*IT.java</exclude></excludes>
    </configuration>
</plugin>
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-failsafe-plugin</artifactId>
    <executions>
        <execution>
            <goals>
                <goal>integration-test</goal>
                <goal>verify</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```

### Pattern: HTTP integration test

```java
@QuarkusTest
@CitrusSupport
class ApiIT {

    @CitrusResource
    TestCaseRunner t;

    @Test
    void postWidget_returnsCreated() {
        t.when(http().client("http://localhost:8080")
            .send().post("/api/widgets")
            .message().contentType("application/json")
            .body("{\"name\": \"test-widget\"}"));

        t.then(http().client("http://localhost:8080")
            .receive().response(HttpStatus.CREATED)
            .message().type(MessageType.JSON)
            .validate(jsonPath()
                .expression("$.name", "test-widget")));
    }
}
```

### Running

```bash
mvn test                    # Layer 1 only (surefire)
mvn verify                  # Layer 1 + 2 (surefire + failsafe)
mvn verify -DskipUnitTests  # Layer 2 only (failsafe)
```

## Layer 3: Newman / Postman API tests

### Postman collection structure

```
test-data/
├── postman/
│   ├── my-service.postman_collection.json
│   └── local.postman_environment.json
```

### Running with Newman

```bash
newman run test-data/postman/my-service.postman_collection.json \
    -e test-data/postman/local.postman_environment.json \
    -r cli,htmlextra \
    --reporter-htmlextra-export test-data/postman/report.html
```

### CI integration

```yaml
test:api:
  stage: test
  image: postman/newman:6-alpine
  script:
    - newman run test-data/postman/*.postman_collection.json
        -e test-data/postman/ci.postman_environment.json
        --reporters cli,junit
        --reporter-junit-export results/newman-report.xml
  artifacts:
    when: always
    reports:
      junit: results/newman-report.xml
```

## Micrometer + OpenTelemetry extensions

Add at project creation for observability from day one:

```bash
quarkus ext add micrometer-registry-prometheus opentelemetry
```

Or in `pom.xml`:

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-micrometer-registry-prometheus</artifactId>
</dependency>
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-opentelemetry</artifactId>
</dependency>
```

### Verifying metrics endpoint

```bash
curl -s http://localhost:8080/q/metrics | grep app_
```

### Verifying health endpoint

```bash
quarkus ext add health
curl -s http://localhost:8080/q/health | jq
```
