package hotel;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.*;
import java.util.Properties;

/**
 * One shared MySQL connection. The schema is NOT created here any more: run the scripts in "dbms project/sql"
 * (README.md there) once. The connection details come from config.properties, never from the source code.
 */
public final class hotel_db {
    // Looked for in the working directory (the project folder in IntelliJ), then in "dbms project".
    private static final String[] CONFIG_PATHS = {"config.properties", "dbms project/config.properties"};
    // Logging in to MySQL takes ~0.4s, so one connection is opened once and reused by every page.
    private static Connection shared;
    private static Properties config;
    private hotel_db() { }
    public static synchronized Connection connect() throws SQLException {
        try {
            if (shared == null || !shared.isValid(2)) {
                shared = open();
            }
            return keepOpen(shared);
        } catch (SQLException e) {
            String msg = String.valueOf(e.getMessage());
            if (msg.contains("No suitable driver")) {
                throw new SQLException("MySQL driver not found. Add mysql-connector-j jar to the project libraries.", e);
            }
            if (msg.contains("Communications link failure") || msg.contains("Connection refused")) {
                throw new SQLException("Cannot reach MySQL on localhost:3306. Start the MySQL server and try again.", e);
            }
            if (msg.contains("Unknown database")) {
                throw new SQLException("Database hotel_mgmt not found. Run the scripts in 'dbms project/sql' first (see README.md there).", e);
            }
            throw e;
        }
    }

    /** Wraps the shared connection so the callers' try-with-resources close() does not really close it. */
    private static Connection keepOpen(Connection real) {
        return (Connection) java.lang.reflect.Proxy.newProxyInstance(
                Connection.class.getClassLoader(), new Class<?>[]{Connection.class},
                (proxy, method, args) -> {
                    if (method.getName().equals("close")) return null;
                    try {
                        return method.invoke(real, args);
                    } catch (java.lang.reflect.InvocationTargetException e) {
                        throw e.getCause();
                    }
                });
    }

    private static Connection open() throws SQLException {
        Properties p = config();
        return DriverManager.getConnection(
                p.getProperty("db.url", "jdbc:mysql://localhost:3306/hotel_mgmt"),
                p.getProperty("db.user", "hotel_app"),
                p.getProperty("db.password"));
    }

    private static Properties config() throws SQLException {
        if (config != null) return config;
        for (String name : CONFIG_PATHS) {
            Path file = Paths.get(name);
            if (!Files.isRegularFile(file)) continue;
            Properties p = new Properties();
            try (InputStream in = Files.newInputStream(file)) {
                p.load(in);
            } catch (IOException e) {
                throw new SQLException("Cannot read " + file.toAbsolutePath() + ": " + e.getMessage(), e);
            }
            if (p.getProperty("db.password") == null) {
                throw new SQLException("db.password is missing in " + file.toAbsolutePath());
            }
            return config = p;
        }
        throw new SQLException("config.properties not found in " + Paths.get("").toAbsolutePath()
                + ". Copy config.properties.example to config.properties and fill in the database password.");
    }
}
