# PI-SEMOB Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the authenticated Flutter view into a navigable SEMOB dashboard, operation, reports, and settings app backed by real MongoDB data.

**Architecture:** Keep the current FastAPI/MongoDB connection and import route. Query actual `relatorios_mensais` structure before choosing aggregations. Build a shared Flutter shell around the current header/drawer, move the existing import UI into Operation, and fetch bounded dashboard/report responses from FastAPI.

**Tech Stack:** Flutter/Dart, `fl_chart`, FastAPI/Python, PyMongo, MongoDB.

**Spec:** `/home/rafaelpalumbo/.codex/attachments/32ad263b-53da-42ae-be96-541316d274c4/Pasted text.txt`

## Global Constraints

- Preserve existing login and ZIP import behavior and visual palette.
- Use only real existing report fields for dashboard metrics.
- Paginate reports and aggregate dashboard data in MongoDB.
- Do not delete data, commit, or push.

## Review Focus

- Empty collection: dashboard and reports show clear empty states.
- Mixed report periods/cadences: totals do not double count overlapping records.
- Invalid filters and pages: API validates input and bounds page size.
- Offline API: dashboard, reports, and settings remain usable with visible errors.
- Navigation during ZIP upload: progress and result survive section changes.

---

### Task 1: Inspect real report data and expose bounded APIs

**Files:** Modify `backend/src/main.py`; create a focused backend query module and tests as appropriate.

**Interfaces:** `GET /dashboard/opcoes`, `/dashboard/resumo`, `/dashboard/evolucao`, `/dashboard/faixas-horarias`, `/dashboard/linhas`; `GET /relatorios` with page, limit, period, type and line filters; `GET /health`.

- [ ] Inspect collection read-only for categories, paths, normalized fields, value types, and period coverage.
- [ ] Write tests for actual metric filters, empty data, report paging, filters, and error paths; confirm failures.
- [ ] Implement MongoDB aggregation and paginated projection with bounded responses.
- [ ] Run backend tests and inspect response payloads from the local API.

### Task 2: Build authenticated shell and preserve import

**Files:** Modify `frontend/lib/homepage.dart`, `frontend/lib/login.dart`, `frontend/lib/auth_service.dart`; create `frontend/lib/operation_page.dart`, `frontend/lib/settings_page.dart`; add Flutter widget tests.

**Interfaces:** `HomePage(usuario: UsuarioAutenticado)` owns navigation and shared header; `DashboardPage()` and `ReportsPage()` are content widgets.

- [ ] Write navigation/login/logout/import preservation tests; confirm failures.
- [ ] Extract the import content and state into Operation, then wire the menu and selected item.
- [ ] Pass the existing login response user into HomePage and Settings.
- [ ] Run Flutter widget tests.

### Task 3: Show real dashboard data

**Files:** Create `frontend/lib/dashboard_page.dart`, `frontend/lib/dashboard_service.dart`; modify `frontend/pubspec.yaml` and lockfile; add Flutter tests.

**Interfaces:** `DashboardPage({DashboardService? service})` uses the task 1 API contract and is embedded in HomePage.

- [ ] Write service/widget tests for real response parsing, filter changes, loading/error/empty states; confirm failures.
- [ ] Add `fl_chart`, then implement cards, relevant charts and line ranking using API values only.
- [ ] Run dashboard tests and `flutter analyze`.

### Task 4: Paginated reports page

**Files:** Create `frontend/lib/reports_page.dart`, `frontend/lib/reports_service.dart` and tests.

**Interfaces:** `ReportsPage({ReportsService? service})` is embedded in HomePage.

- [ ] Write service/widget tests for filters, pagination and details; confirm failures.
- [ ] Implement bounded API fetching and responsive list/table with page controls.
- [ ] Run reports tests and `flutter analyze`.

### Task 5: Integrate and verify

**Files:** Update `README.md` for endpoints, metrics, dependencies and launch instructions.

- [ ] Review all changes against the source data and full spec.
- [ ] Run `flutter analyze`, `flutter test`, Python tests, and a Flutter Web build.
- [ ] Exercise local API login, dashboard and report endpoints; keep ZIP import regression checked.
- [ ] Report actual schema, metrics, endpoints, files, launch steps, and test results.
