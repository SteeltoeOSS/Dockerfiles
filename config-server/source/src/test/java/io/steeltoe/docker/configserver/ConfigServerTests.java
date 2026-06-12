package io.steeltoe.docker.configserver;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Default configuration: {@code auth.enabled=false}, so {@code BasicOrNoAuthConfig}
 * wires the permit-all security chain. The config-server health contributor is
 * disabled here so the test never reaches out to the configured git repository.
 */
@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {
                "spring.cloud.config.server.health.enabled=false",
                "spring.cloud.config.server.git.cloneOnStart=false"
        })
class ConfigServerTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void contextLoads() {
    }

    @Test
    void healthIsOpenWhenAuthDisabled() {
        ResponseEntity<String> response = restTemplate.getForEntity("/actuator/health", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).contains("UP");
    }
}
