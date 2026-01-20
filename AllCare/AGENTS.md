# Repository Guidelines

## Project Structure & Module Organization
- Flutter app lives in `lib/` with pages under `lib/pages/`, features in `lib/features/` (case flow, login), shared services in `lib/services/`, and theme assets in `lib/theme/`. Shared routing and app state are at the root (`main.dart`, `routes.dart`, `app_state.dart`).
- Assets (UI images, mock credentials, bundled models) are in `assets/`; keep image/model additions small and referenced in `pubspec.yaml`.
- Backend (FastAPI + PyTorch) is in `backserver/` with entrypoint `back.py`, config in `config.py`, and schemas in `schemas.py`. Runtime metadata writes to `backserver/storage/metadata.jsonl`.
- Platform scaffolding is in `android/`, `ios/`, `web/`, etc.; Flutter tests live in `test/`. Avoid editing `build/` outputs.

## Build, Test, and Development Commands
- Install deps: `flutter pub get`.
- Run app (Android emulator host): `flutter run --dart-define=BACKSERVER_BASE=http://10.0.2.2:8000 --dart-define=API_KEY=<optional>`.
- Lint: `flutter analyze`.
- Format: `dart format .` (respects `analysis_options.yaml`).
- Flutter tests: `flutter test`.
- Backend: `cd backserver && python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt && PYTHONPATH=. uvicorn back:app --host 0.0.0.0 --port 8000`.

## Coding Style & Naming Conventions
- Dart: 2-space indent, prefer `const` constructors, and keep widget/state class names in `PascalCase`; files in `snake_case.dart`.
- Follow lints in `analysis_options.yaml`; fix analyzer warnings before pushing.
- Keep network/config values in `lib/features/case/api_config.dart` sourced via `--dart-define`; do not hardcode secrets.
- Backend: Python 3.10+, type hints encouraged; keep route handlers in `back.py` and shared models in `schemas.py`.

## Testing Guidelines
- Place Flutter tests in `test/` with `_test.dart` suffix; organize by feature (e.g., `test/features/case/`).
- Prefer widget tests around login flow and case creation; mock network calls when feasible.
- Run `flutter test` locally before PRs; add coverage notes for major features.

## Commit & Pull Request Guidelines
- Commits: short imperative subject (<72 chars), e.g., `Fix blur check dialog` or `Add case summary deletion`.
- PRs: include what/why, screenshots for UI changes, repro steps for bug fixes, and backend/frontend flags used (`--dart-define` values, env vars).
- Link related issues or TODO items; mention platform(s) tested (Android emulator, iOS simulator, backend local). Avoid committing secrets or large model binaries beyond existing assets.
