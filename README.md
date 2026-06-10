# MindVault

MindVault is a graph-first personal knowledge management system. V1 focuses on knowledge bases, nodes, Markdown documents, dynamic graph browsing, and global search.

## Repository Layout

- `backend/` - Spring Boot 3 monolith API, Java 21, PostgreSQL 16.
- `frontend/` - Flutter Material 3 client for Android, iOS, and Web.
- `docs/` - Product, API, and local development notes.

## Local Prerequisites

- Java 21
- Maven 3.9+
- Flutter SDK
- PostgreSQL 16

## Backend

```powershell
.\scripts\run-backend.ps1
```

The API runs at `http://localhost:8080/api`.

## Frontend

```powershell
cd frontend
..\scripts\flutter-env.ps1
flutter pub get
flutter analyze
flutter test
```

The Flutter API client defaults to `http://localhost:8080/api`.

For local API smoke testing after the backend is running:

```powershell
.\scripts\api-smoke.ps1
```
