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
Choosing another role is a local navigation preview, not fixture data or
authentication. Backend, API, Dio, and Supabase integrations are not included.

Run with `flutter pub get` and `flutter run`.
