package demo.startup;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import java.lang.management.ManagementFactory;
import java.util.Map;

@SpringBootApplication
@RestController
public class StartupDemoApp {

    private static final long JVM_START_MS =
        ManagementFactory.getRuntimeMXBean().getStartTime();
    private static final long APP_READY_MS = System.currentTimeMillis();

    public static void main(String[] args) {
        SpringApplication.run(StartupDemoApp.class, args);
    }

    @GetMapping("/")
    public Map<String, Object> home() {
        return Map.of(
            "app",       "spring-startup-demo",
            "framework", "Spring Boot 4.0.5",
            "java",      System.getProperty("java.version"),
            "startupMs", APP_READY_MS - JVM_START_MS
        );
    }

    @GetMapping("/startup-time")
    public Map<String, Object> startupTime() {
        var flags = ManagementFactory.getRuntimeMXBean().getInputArguments();
        boolean cdsActive = flags.stream().anyMatch(f ->
            f.contains("SharedArchiveFile") || f.contains("Xshare:on"));
        return Map.of(
            "totalStartupMs", APP_READY_MS - JVM_START_MS,
            "jvmVersion",     System.getProperty("java.vm.name") + " " +
                              System.getProperty("java.version"),
            "appcdsActive",   cdsActive,
            "note",           "JPA + Hibernate loaded to simulate real-world class loading"
        );
    }
}

// JPA entity — forces Hibernate to initialise, loads ~3000 extra classes
@Entity
class StartupEvent {
    @Id @GeneratedValue
    Long id;
    String label;
    long timestampMs;
}

interface StartupEventRepository extends JpaRepository<StartupEvent, Long> {}
