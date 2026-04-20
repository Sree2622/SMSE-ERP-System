# Smart Kirana — Total Polish Plan

## Product North Star (next 6–8 weeks)
Transform Smart Kirana from a capable prototype into a resilient retail operations app that feels fast, trustworthy, and delightful during daily store workflows (inventory updates, billing, reporting, and settings).

---

## 1) UI/UX Refinement

### A. 80/20 Friction Hotspots (the 20% causing 80% of pain)

#### 1) Dense action surfaces in `BillingScreen` and `ScanScreen`
- Current issue: camera, AI actions, list controls, and confirmation CTAs are all on one screen competing for attention.
- Impact: decision fatigue and accidental taps during rapid billing/scanning.
- Improvement:
  - Introduce a **3-zone layout**: Capture Zone (camera), Review Zone (detected/cart items), Commit Zone (sticky CTA).
  - Reduce competing button prominence: only one primary action visible per state.
  - Add section headers with helper microcopy.

#### 2) Inconsistent empty states
- Current issue: mostly plain text fallbacks (`No inventory items...`, `No items match...`) with no directional guidance.
- Impact: users do not know next best action.
- Improvement:
  - Add **illustrated empty-state cards** + one clear CTA:
    - No inventory → “Add your first item” button.
    - No search results → “Clear filters” action.
    - No bills/history → “Create first bill” action.

#### 3) Visual hierarchy + token inconsistency
- Current issue: repeated ad-hoc colors, rounded corners, and spacing values across screens.
- Impact: app feels stitched together rather than designed systemically.
- Improvement:
  - Define design tokens (`AppSpacing`, `AppRadius`, `AppTextStyles`, semantic colors).
  - Use an 8pt grid, with standard paddings (16/24) and section gaps (12/20/28).
  - Standardize card shell + tile patterns in shared widgets.

### B. Typography & Spacing Improvements (Visual Hierarchy)
- Set explicit scale:
  - H1: 24/32 semi-bold (dashboard and page titles)
  - H2: 18/26 semi-bold (section titles)
  - Body: 14/20 regular
  - Meta: 12/16 medium (supporting text, status labels)
- Increase vertical rhythm:
  - Replace tight clusters of controls with grouped “content blocks”.
  - Keep action buttons separated from lists by min 12–16dp.
- Improve readability:
  - Limit line lengths in status/error text.
  - Ensure secondary text uses stable contrast (not below WCAG AA).

### C. Micro-interactions to Make It Feel Alive

#### Loading states
- Replace global spinners with skeletons/shimmers:
  - Dashboard cards (home/reports)
  - Inventory list rows
  - Billing history carousel cards

#### Tactile/feedback behaviors
- Add haptic feedback on mobile:
  - Light impact: quantity +/- taps
  - Medium impact: successful scan detection merge
  - Heavy impact: bill generation success
- Success/error animation moments:
  - Use checkmark pulse on save/generate success.
  - Use shake + inline hint on invalid form submit.

#### Timing standards
- Success toasts/snackbars: 1.6–2.2s
- Button loading states: show spinner only after ~150ms to avoid flicker
- Error retry cards: include backoff hint after repeated failures

### D. Accessibility Audit Targets
- Contrast:
  - Audit gradients + white text for AA compliance.
  - Avoid low-contrast grey body text on white cards.
- Touch targets:
  - Ensure all icon-only buttons are >=48x48dp.
  - Increase chip/filter tap areas and spacing.
- Semantics & screen readers:
  - Add `Semantics` labels for camera actions, increment/decrement controls, and critical CTAs.
  - Ensure snackbar messages are mirrored in accessible announcements.

---

## 2) Fixing Missing Pieces (Edge Case Resilience)

### A. Connectivity, Offline, and Latency Strategy

#### Data strategy by workflow
- Inventory and bills are mission-critical; support **offline-first reads + queued writes**.
- Recommended local persistence:
  - `Hive` for fast key/value caching of lightweight views (dashboard summary, user prefs)
  - `sqflite` for relational/offline queues (pending bill/inventory mutations)

#### State model
- Introduce `LoadState<T>` envelope:
  - `fresh`, `stale_cached`, `loading`, `error_retriable`, `error_terminal`
- Every screen should render one of these states explicitly.

#### Retry/backoff
- API/Firestore operation wrappers with exponential backoff + jitter
  - e.g., 0.4s, 0.9s, 1.8s, cap 5s
- Display inline retry affordance after first failure.

#### User-visible network UX
- Add global online/offline banner.
- Show “Last synced X min ago” on inventory/reports pages.
- Queue saves when offline and show a “Pending Sync” badge with count.

### B. Input Validation: Regex + Domain Logic

#### Inventory Item Name
- Regex: `^[A-Za-z0-9][A-Za-z0-9 .,&()'/-]{1,59}$`
- Rules:
  - Trim and collapse repeated spaces.
  - Block all-whitespace and punctuation-only names.

#### Stock Quantity
- Regex: `^\d{1,5}$`
- Logic:
  - Range: 0–99999
  - For edits, warn if drop >80% from prior stock to prevent accidental overwrite.

#### Price
- Regex: `^\d{1,6}(\.\d{1,2})?$`
- Logic:
  - Range: 0.01–999999.99
  - Reject negative and malformed decimal separators.

#### GST Number (India)
- Regex: `^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$`
- Logic:
  - Auto-uppercase before validation.
  - Provide helper text format example.

#### Search fields
- Never fail hard; sanitize and normalize only.
- Ignore unsupported symbols rather than rejecting input.

### C. Global Error Boundary / Crash Safety

Implement a layered safety net:
1. `runZonedGuarded` around app bootstrap.
2. `FlutterError.onError` + `PlatformDispatcher.instance.onError` forwarding to logger/crash reporter.
3. Root `AppErrorBoundary` widget:
   - catches build-time subtree exceptions,
   - renders friendly fallback with **Retry** and **Back to Home**,
   - logs diagnostic context (route, action id, user/session id).

Create unified error UI variants:
- Data fetch failure card (retriable)
- Empty-but-healthy state
- Terminal error state (support contact + incident id)

---

## 3) Operational Oil (Efficiency & Maintainability)

### A. State Management Audit

Current pattern is mostly local `setState` + `FutureBuilder/StreamBuilder`.

#### Risks
- Rebuild scope is broad (whole screen updates for small quantity changes).
- Repeated query/transform logic in multiple screens.
- Potential duplicate analyzer/camera state logic between billing and scan.

#### Recommendation path
- Short term: introduce `ValueNotifier`/`ChangeNotifier` for cart + scan maps.
- Medium term: migrate to Riverpod (or Bloc if team preference) for:
  - repository providers
  - derived selectors (totals/counts)
  - mutation commands with loading/error state
- Extract reusable “VisionCaptureController” shared by Billing and Scan modules.

### B. Logging & Telemetry

#### Logging stack
- Flutter app logs: `logger` with environment-based level + pretty/dev and JSON/prod outputs.
- Backend/ops pipeline: pipe JSON logs into Cloud Logging/Datadog/Sentry.

#### Events to track
- Screen viewed
- Camera initialized / failed
- Analyze started / success / empty / failed
- Bill generate attempt / success / partial (out-of-stock skipped) / failure
- Inventory add/edit/delete

#### Crash + performance telemetry
- Add Sentry (or Firebase Crashlytics) for exceptions.
- Add performance spans around:
  - Firestore reads/writes
  - image analysis duration
  - bill generation end-to-end latency

### C. Build & Deployment Optimization Checklist

#### Flutter bundle size
- Enable tree-shaking icons.
- Remove unused assets/fonts and package dependencies.
- Prefer deferred components for rarely used flows (if needed at scale).
- Audit native permissions; remove unused camera/gallery/platform permissions.

#### Runtime performance
- Use `const` constructors where possible.
- Reduce nested rebuilds via extracted widgets + selectors.
- Paginate history/report lists beyond small limits.

#### Docker/CI optimization
- Multi-stage Docker builds.
- Order layers for cache hits (dependencies before source copy when possible).
- Pin base image digests.
- Keep `.dockerignore` strict (exclude build artifacts, test caches, docs if not needed).

---

## Prioritized Implementation Roadmap

## Quick Wins (10-minute to ~1 hour fixes)
1. Add standardized empty-state cards with CTA on Inventory, Billing, Reports.
2. Replace spinner-only list loading with shimmer placeholders.
3. Add `Semantics` labels and increase icon tap targets to 48dp.
4. Add form validators for item name, stock, price, GST with inline messages.
5. Introduce centralized spacing/text style constants and apply to top-level screens.
6. Add retry button on all Firestore error states.
7. Add lightweight app-wide logging wrapper and instrument key user actions.
8. Add offline banner driven by connectivity stream.

## Deep Refactors (structural changes)
1. Introduce repository + state layer (Riverpod/Bloc) and remove ad-hoc state duplication.
2. Build a shared camera/vision module used by both Billing and Scan.
3. Implement offline queue + local cache with sync reconciliation policies.
4. Add global error boundary architecture + unified error UI kit.
5. Build design system package (tokens + components + interaction specs).
6. Add telemetry dashboards and SLOs (error rate, sync success, bill latency).
7. Implement CI/CD optimization pipeline (build cache, image slimming, artifact profiling).

---

## Suggested 30/60/90 Execution
- **30 days:** quick wins + validation + empty/loading/error UX consistency.
- **60 days:** state layer and shared modules, offline queue v1, structured logs.
- **90 days:** design system maturity, observability dashboards, release hardening.
