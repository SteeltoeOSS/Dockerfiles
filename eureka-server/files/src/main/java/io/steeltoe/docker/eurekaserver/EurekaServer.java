package io.steeltoe.docker.eurekaserver;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;

@SpringBootApplication
@EnableEurekaServer
public class EurekaServer {

    private static final Logger logger = LoggerFactory.getLogger(EurekaServer.class);

    public static void main(String[] args) {
        Package pkg = EnableEurekaServer.class.getPackage();
        logger.info("{} {} by {}", pkg.getImplementationTitle(), pkg.getImplementationVersion(), pkg.getImplementationVendor());
        SpringApplication.run(EurekaServer.class, args);
    }

}
