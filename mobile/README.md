# Dampingi Flutter foundation

The app is organized into `models`, `services`, `routes`, `core`, and
role-specific `features`. Role entry pages are intentionally placeholders.
Riverpod stores the role loaded from the local profile fixture and GoRouter
provides the role entry routes.

The repository does not contain the referenced `contracts/fixtures`,
`contracts/api`, `contracts/schemas`, `docs/architecture.md`, or
`docs/api-contracts.md`. The only available profile capture is
`assets/fixtures/profiles-select-2026-11-09.json`; it contains a `mother` role.
`professional` is the project role value displayed through `DoctorPage`.
The app starts in local preview mode so its screens can be inspected without
backend access. Sign in with `demo.mother@dampingi.test` and `demo1234`, then
open **Rekomendasi** in the bottom navigation to view chat. In preview mode,
chat messages are not sent to an AI service.

To switch authentication and chat to the existing backend, provide its URL and
enable backend authentication at build/run time; no API secrets belong in the
app:

```sh
flutter run --dart-define=API_BASE_URL=https://<backend-host> --dart-define=USE_BACKEND_AUTH=true
```

Backend chat requires a valid account with the `mother` role. Local preview
authentication uses mock accounts and cannot access backend chat.
