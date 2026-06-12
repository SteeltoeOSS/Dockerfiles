package io.steeltoe.docker.springbootadmin;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Spring Boot Admin ships no actuator endpoint of its own, so the useful check is that the
 * admin server boots with the committed dependencies and serves its UI. This is the
 * regression signal we want when bumping Spring Boot / Spring Boot Admin versions.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class SpringBootAdminTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void contextLoads() {
    }

    @Test
    void adminUiIsServed() {
        ResponseEntity<String> response = restTemplate.getForEntity("/", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }
}
