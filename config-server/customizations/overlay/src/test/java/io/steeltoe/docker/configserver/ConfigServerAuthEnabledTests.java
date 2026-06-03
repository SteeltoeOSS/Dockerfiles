package io.steeltoe.docker.configserver;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * With {@code auth.enabled=true}, {@code BasicOrNoAuthConfig} wires the HTTP Basic
 * security chain plus an in-memory user. This verifies that custom logic end to end:
 * unauthenticated requests are rejected and valid credentials are accepted.
 */
@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {
                "auth.enabled=true",
                "auth.username=tester",
                "auth.password=secret",
                "spring.cloud.config.server.health.enabled=false",
                "spring.cloud.config.server.git.cloneOnStart=false"
        })
class ConfigServerAuthEnabledTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void rejectsRequestsWithoutCredentials() {
        ResponseEntity<String> response = restTemplate.getForEntity("/actuator/health", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void acceptsRequestsWithValidCredentials() {
        ResponseEntity<String> response = restTemplate
                .withBasicAuth("tester", "secret")
                .getForEntity("/actuator/health", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).contains("UP");
    }
}
