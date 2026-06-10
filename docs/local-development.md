# Local Development

## Required Tools

- Java 21 for the backend.
- Maven 3.9 or newer.
- Flutter SDK for Android, iOS, and Web builds.
- PostgreSQL 16 running locally.

The initial machine inspection found Maven installed, but Java 17 was active and Flutter/psql were not on PATH. Install or configure those tools before full verification.

## PostgreSQL

Create a local database named `mindvault`.

```sql
CREATE DATABASE mindvault;
```

The backend local profile expects:

- Host: `localhost`
- Port: `5432`
- Database: `mindvault`
- Username: `postgres`
- Password: environment variable `MINDVAULT_DB_PASSWORD`

## Local Environment Scripts

Local machine scripts are intentionally ignored by Git because they may contain
absolute SDK paths or passwords. Create them from the examples:

```powershell
Copy-Item .\scripts\backend-env.example.ps1 .\scripts\backend-env.ps1
Copy-Item .\scripts\flutter-env.example.ps1 .\scripts\flutter-env.ps1
```

Then edit the copied files for your machine.

## Run Backend

```powershell
.\scripts\run-backend.ps1
```

## Run Frontend

```powershell
cd frontend
..\scripts\flutter-env.ps1
flutter pub get
flutter analyze
flutter test
```

To launch manually for web after checks pass:

```powershell
flutter run -d chrome
```

## Test Strategy

Backend tests use a test-only H2 database in PostgreSQL compatibility mode so entity mapping tests can run without requiring a local PostgreSQL server. Runtime and local development remain PostgreSQL-first.
