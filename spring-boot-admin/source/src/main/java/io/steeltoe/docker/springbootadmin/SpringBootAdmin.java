package io.steeltoe.docker.springbootadmin;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import de.codecentric.boot.admin.server.config.EnableAdminServer;

@SpringBootApplication
@EnableAdminServer
public class SpringBootAdmin {

	private static final Logger logger = LoggerFactory.getLogger(SpringBootAdmin.class);

	public static void main(String[] args) {
        Package pkg = EnableAdminServer.class.getPackage();
        logger.info("{} {} by {}", pkg.getImplementationTitle(), pkg.getImplementationVersion(), pkg.getImplementationVendor());
		SpringApplication.run(SpringBootAdmin.class, args);
	}

}
