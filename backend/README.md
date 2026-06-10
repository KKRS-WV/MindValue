# MindVault Backend

Spring Boot 3 monolith API for MindVault V1.

## Run

```powershell
$env:MINDVAULT_DB_PASSWORD="your-postgres-password"
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

## Test

The project requires Java 21.

```powershell
mvn test
```

If you are temporarily validating syntax on a Java 17 machine, this compatibility check can be used, but it is not the project target:

```powershell
mvn test "-Djava.version=17"
```
