package demo.startup;

import io.quarkus.test.junit.QuarkusIntegrationTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.notNullValue;

/**
 * Integration test that runs against the packaged quarkus-run.jar.
 * When quarkus.package.jar.aot.enabled=true, the Quarkus Maven plugin
 * uses this test suite as the AOT training workload — the JVM records
 * class loading and JIT profiles from these requests, then writes app.aot.
 */
@QuarkusIntegrationTest
class StartupResourceIT {

    @Test
    void testHome() {
        given().when().get("/")
            .then().statusCode(200)
            .body("startupMs", notNullValue());
    }

    @Test
    void testStartupTime() {
        given().when().get("/startup-time")
            .then().statusCode(200)
            .body("totalStartupMs", notNullValue());
    }

    @Test
    void testHealth() {
        given().when().get("/q/health/live")
            .then().statusCode(200);
    }
}
