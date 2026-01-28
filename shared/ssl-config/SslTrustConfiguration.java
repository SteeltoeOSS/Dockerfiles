package io.steeltoe.docker.ssl;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.KeyStore;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.List;
import javax.security.auth.x500.X500Principal;

/**
 * SSL Trust Configuration
 *
 * This configuration class provides SSL certificate trust support for development environments.
 * It automatically loads certificates from environment variables or standard locations and
 * creates a custom TrustManager that trusts both standard CA certificates and development
 * certificates (e.g., Aspire development certificates).
 *
 * <p>Certificate locations checked (in order):
 * <ul>
 *   <li>{@code SSL_CERT_DIR} environment variable (directory containing certificates)</li>
 *   <li>{@code /usr/lib/ssl/aspire} (default development certificate directory, e.g., for Aspire)</li>
 *   <li>{@code SSL_CERT_FILE} environment variable (single certificate file)</li>
 * </ul>
 *
 * <p>Supported certificate formats: .pem, .crt, .cer
 *
 * <p>Example usage with Aspire:
 * <pre>
 * // Aspire automatically sets SSL_CERT_DIR or mounts certificates at /usr/lib/ssl/aspire
 * // This configuration will automatically detect and trust those certificates
 * </pre>
 */
@Configuration
public class SslTrustConfiguration {

    private static final Logger logger = LoggerFactory.getLogger(SslTrustConfiguration.class);

    @Bean
    public X509TrustManager sslTrustManager() {
        try {
            TrustManagerFactory defaultTmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
            defaultTmf.init((KeyStore) null);
            javax.net.ssl.TrustManager[] trustManagers = defaultTmf.getTrustManagers();
            if (trustManagers == null || trustManagers.length == 0 || !(trustManagers[0] instanceof X509TrustManager)) {
                throw new IllegalStateException("No X509TrustManager available from default TrustManagerFactory");
            }
            X509TrustManager defaultTrustManager = (X509TrustManager) trustManagers[0];

            List<X509Certificate> devCerts = loadDevelopmentCertificates();
            if (devCerts.isEmpty()) {
                logger.info("SSL trust: Using default trust manager (no development certificates found)");
                return defaultTrustManager;
            }

            logger.info("SSL trust: Loaded {} development certificate(s)", devCerts.size());
            return new X509TrustManager() {
                @Override
                public void checkClientTrusted(X509Certificate[] chain, String authType) throws CertificateException {
                    defaultTrustManager.checkClientTrusted(chain, authType);
                }

                @Override
                public void checkServerTrusted(X509Certificate[] chain, String authType) throws CertificateException {
                    try {
                        defaultTrustManager.checkServerTrusted(chain, authType);
                    } catch (CertificateException e) {
                        // If default validation fails, check if any certificate in the chain
                        // is signed by or matches a development certificate
                        logger.debug("Default trust validation failed, checking development certificates...");
                        for (X509Certificate cert : chain) {
                            X500Principal certSubject = cert.getSubjectX500Principal();
                            logger.trace("Checking certificate: {}", certSubject);
                            
                            // Check if this certificate matches or is signed by a dev cert
                            for (X509Certificate devCert : devCerts) {
                                // First check for exact match
                                if (cert.equals(devCert)) {
                                    logger.debug("Trusting certificate (exact match with development cert): {}", certSubject);
                                    return;
                                }
                                
                                // Then verify cryptographic signature
                                // Only trust certs signed by dev CAs if the dev cert is actually a CA
                                try {
                                    // Check if dev cert has CA basic constraints
                                    boolean isCA = devCert.getBasicConstraints() != -1;
                                    if (!isCA) {
                                        logger.trace("Development cert is not a CA, skipping signature verification: {}", devCert.getSubjectX500Principal());
                                        continue;
                                    }
                                    
                                    // Verify that the cert was signed by the dev cert
                                    cert.verify(devCert.getPublicKey());
                                    logger.debug("Trusting certificate signed by development CA: {}", certSubject);
                                    return; // Trusted by development CA
                                } catch (Exception verifyException) {
                                    // Signature verification failed, continue checking other dev certs
                                    logger.trace("Signature verification failed for cert {} with dev cert {}: {}", 
                                        certSubject, devCert.getSubjectX500Principal(), verifyException.getMessage());
                                }
                            }
                        }
                        // If we get here, the certificate chain doesn't include any development certificates
                        logger.warn("Certificate validation failed and no development certificate found in chain");
                        throw e;
                    }
                }

                @Override
                public X509Certificate[] getAcceptedIssuers() {
                    X509Certificate[] defaultCerts = defaultTrustManager.getAcceptedIssuers();
                    X509Certificate[] allCerts = new X509Certificate[defaultCerts.length + devCerts.size()];
                    System.arraycopy(defaultCerts, 0, allCerts, 0, defaultCerts.length);
                    System.arraycopy(devCerts.toArray(new X509Certificate[0]), 0, allCerts, defaultCerts.length, devCerts.size());
                    return allCerts;
                }
            };
        } catch (Exception e) {
            logger.error("Failed to create SSL trust manager, using default", e);
            try {
                TrustManagerFactory defaultTmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
                defaultTmf.init((KeyStore) null);
                javax.net.ssl.TrustManager[] trustManagers = defaultTmf.getTrustManagers();
                if (trustManagers == null || trustManagers.length == 0 || !(trustManagers[0] instanceof X509TrustManager)) {
                    throw new IllegalStateException("No X509TrustManager available from default TrustManagerFactory");
                }
                return (X509TrustManager) trustManagers[0];
            } catch (Exception ex) {
                logger.error("Failed to create default trust manager", ex);
                throw new RuntimeException("Failed to create trust manager", ex);
            }
        }
    }

    private List<X509Certificate> loadDevelopmentCertificates() {
        List<X509Certificate> certificates = new ArrayList<>();
        logger.debug("Loading development certificates...");
        try {
            CertificateFactory certFactory = CertificateFactory.getInstance("X.509");
            String[] certPaths = {
                System.getenv("SSL_CERT_DIR"),
                "/usr/lib/ssl/aspire",
                System.getenv("SSL_CERT_FILE")
            };

            logger.trace("Checking certificate paths: SSL_CERT_DIR={}, /usr/lib/ssl/aspire, SSL_CERT_FILE={}",
                System.getenv("SSL_CERT_DIR"), System.getenv("SSL_CERT_FILE"));

            for (String certPath : certPaths) {
                if (certPath == null) continue;
                Path path = Paths.get(certPath);
                if (Files.isDirectory(path)) {
                    logger.debug("Scanning directory for certificates: {}", certPath);
                    try (var stream = Files.walk(path)) {
                        stream.filter(Files::isRegularFile)
                            .filter(p -> p.toString().matches(".*\\.(pem|crt|cer)$"))
                            .forEach(p -> {
                                try {
                                    try (var inputStream = Files.newInputStream(p)) {
                                        certificates.add((X509Certificate) certFactory.generateCertificate(inputStream));
                                        logger.debug("Loaded certificate: {}", p);
                                    }
                                } catch (Exception e) {
                                    logger.warn("Failed to load certificate {}: {}", p, e.getMessage());
                                }
                            });
                    }
                } else if (Files.isRegularFile(path)) {
                    try (var inputStream = Files.newInputStream(path)) {
                        certificates.add((X509Certificate) certFactory.generateCertificate(inputStream));
                        logger.debug("Loaded certificate: {}", path);
                    } catch (Exception e) {
                        logger.warn("Failed to load certificate {}: {}", path, e.getMessage());
                    }
                }
            }
        } catch (Exception e) {
            logger.error("Error loading development certificates", e);
        }
        return certificates;
    }
}
