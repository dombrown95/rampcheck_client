# RampCheck

RampCheck is a cross-platform Flutter application that supports aircraft ramp inspection workflows.  

It allows users to create jobs, complete inspection checklists, attach evidence and synchronise results with a remote backend API.

The application is designed to work offline-first, with local persistence and explicit synchronisation.

---

## Features

- User authentication (login / account creation)
- Job creation, grouping, and status tracking
- Inspection checklists with pass / fail / N/A results
- File attachments per job
- Offline-first local storage
- Manual and automatic job synchronisation
- Cross-platform support (desktop and Android)

---

## Architecture Overview

The application follows a layered architecture:

- **UI layer**: Flutter screens and widgets
- **Domain models**: `Job`, `InspectionItem`, `Attachment`, `Session`
- **Local persistence**: `LocalStore` abstraction
- **Remote API**: `ApiClient` abstraction
- **Sync engine**: Centralised business logic for data synchronisation

This separation enables clear responsibility boundaries and effective unit testing.

---

## Testing Strategy

Automated testing focuses on validating core business logic rather than UI appearance.

### Unit Tests

The `SyncEngine` is covered by a comprehensive set of unit tests that validate:

- Successful sync of pending jobs
- Failure handling when the API is unavailable
- Correct transition of job sync states (`pending → syncing → clean / failed`)
- Correct mapping of job statuses to API log statuses
- Inclusion of inspection items and attachments in sync payloads
- Fallback behaviour from `createUser` to `login` when user creation fails
- Correct propagation of user IDs into API calls
- Handling of multiple jobs and edge cases (e.g. no pending jobs)

External dependencies are replaced with fake implementations (`FakeStore`, `FakeApi`) to ensure tests are deterministic and isolated.

### Continuous Integration

All tests are executed automatically using **GitHub Actions** on every push and pull request.  
This ensures regressions are detected early and that the codebase remains in a consistently testable state.

---

## Manual API Testing

In addition to automated tests, API endpoints were validated manually using **Postman** to confirm:

- Authentication flows
- Log creation endpoints
- Request and response payload formats

This provides system-level confidence alongside unit-level verification.

---

## Running Tests Locally

```
flutter test
```

## Building and Running
```
flutter pub get
flutter run
```
For Android emulator usage, the API base URL is automatically configured to use 10.0.2.2.