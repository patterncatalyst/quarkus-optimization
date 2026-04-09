package demo.leyden;

import io.quarkus.test.junit.QuarkusIntegrationTest;
import io.restassured.RestAssured;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.*;

/**
 * Demo 04 — AOT Cache Integration Test
 *
 * This test class uses @QuarkusIntegrationTest — it runs against the
 * PACKAGED quarkus-run.jar, not the dev-mode classpath.
 *
 * When quarkus.package.jar.aot.enabled=true is set, the Quarkus Maven
 * plugin runs this test suite as the AOT TRAINING WORKLOAD:
 *
 *   ./mvnw verify
 *     → packages the app
 *     → starts quarkus-run.jar
 *     → runs these @QuarkusIntegrationTest tests against it
 *     → JVM records class loading + linking + JIT profiles
 *     → writes target/quarkus-app/app.aot on shutdown
 *
 * The more representative your integration tests are of production traffic,
 * the better the resulting AOT cache quality (more hot paths pre-profiled).
 *
 * Contrast with @QuarkusTest (no annotation change needed — that runs in
 * dev-mode JVM and does NOT contribute to the AOT cache).
 */
@QuarkusIntegrationTest
class LeydenResourceIT {

    @Test
    void testHomeEndpoint() {
        given()
            .when().get("/")
            .then()
            .statusCode(200)
            .body("app",     equalTo("quarkus-leyden-demo"))
            .body("quarkus", equalTo("3.33.1 LTS"))
            .body("startupMs", notNullValue());
    }

    @Test
    void testStartupMetrics() {
        given()
            .when().get("/startup")
            .then()
            .statusCode(200)
            .body("startupMs",      notNullValue())
            .body("jvmVersion",     notNullValue())
            .body("pid",            notNullValue())
            .body("aotCacheStatus", notNullValue());
    }

    @Test
    void testJvmFlags() {
        given()
            .when().get("/jvm/flags")
            .then()
            .statusCode(200)
            .body("aotFlags",       notNullValue())
            .body("gcFlags",        notNullValue())
            .body("containerFlags", notNullValue());
    }

    @Test
    void testHealthEndpoint() {
        given()
            .when().get("/q/health/live")
            .then()
            .statusCode(200)
            .body("status", equalTo("UP"));
    }
}
