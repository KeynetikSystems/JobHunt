# Implementation Plan - App Refactoring (Critique Fixes)

This plan addresses recommendations 2 (Settings Refactor), 3 (UI/UX Improvements), and 4 (Data Layer Cleanup) from the initial critique.

## User Review Required

> [!IMPORTANT]
> This refactor introduces a `SettingsController` using Flutter's built-in `ChangeNotifier`. I will NOT be adding external state management libraries (like Provider or Riverpod) unless requested, to keep the dependency footprint small.

## Proposed Changes

### 1. Data Layer & Persistence [Recommendation 4]

Unify the data models and extract persistence logic from the API client.

#### [NEW] [feed_item.dart](file:///E:/OpprtunitySCraper/mobile_app/lib/models/feed_item.dart)
*   Create a base interface/mixin for items that appear in the feed (Jobs/News).
*   Add a `toHistory()` method to simplify conversion.

#### [MODIFY] [job_listing.dart](file:///E:/OpprtunitySCraper/mobile_app/lib/models/job_listing.dart) & [news_item.dart](file:///E:/OpprtunitySCraper/mobile_app/lib/models/news_item.dart)
*   Implement `FeedItem`.

#### [MODIFY] [api_client.dart](file:///E:/OpprtunitySCraper/mobile_app/lib/api_client.dart)
*   Remove `SharedPreferences` logic.
*   Focus purely on HTTP networking.

#### [NEW] [auth_service.dart](file:///E:/OpprtunitySCraper/mobile_app/lib/auth_service.dart)
*   Handle registration, login state, and persistence of API keys.

---

### 2. UI/UX & Theming [Recommendation 3]

Improve theme usage and UI components.

#### [MODIFY] [theme.dart](file:///E:/OpprtunitySCraper/mobile_app/lib/theme.dart)
*   Expand `ThemeData` to include button themes, input decoration themes, and more semantic colors.

#### [MODIFY] Widgets in `lib/widgets/`
*   Replace hardcoded `LedgerColors` with `Theme.of(context).colorScheme` or `Theme.of(context).textTheme`.

---

### 3. Settings Screen Refactor [Recommendation 2]

Break down the massive settings screen and introduce a controller.

#### [NEW] [settings_controller.dart](file:///E:/OpprtunitySCraper/mobile_app/lib/screens/settings_controller.dart)
*   A `ChangeNotifier` to manage form states, loading indicators, and section expansion states.

#### [NEW] `lib/screens/settings_sections/`
*   Create small, stateless widgets for each section:
    *   `ProfileSection`
    *   `AlertsSection`
    *   `AccountSection`
    *   `BackendSection`

#### [MODIFY] [settings_screen.dart](file:///E:/OpprtunitySCraper/mobile_app/lib/screens/settings_screen.dart)
*   Rebuild using the controller and the new section widgets.
*   Use `ExpansionTile` for a more idiomatic collapsing behavior.

## Verification Plan

### Automated Tests
*   Run `flutter test` to ensure existing widgets still render.

### Manual Verification
1.  Verify that searching and history still work correctly with the new models.
2.  Test the "Connect" flow in Settings to ensure persistence (AuthService) works.
3.  Check UI rendering on different screen sizes to ensure `ExpansionTile` behaves well.
4.  Switch between Dashboard/History/Settings and ensure state is maintained.
