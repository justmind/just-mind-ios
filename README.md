# Just Mind — iOS Companion App

A native iOS 17+ companion app for clients of Just Mind Counseling (Austin, TX).
Tracks mood and the RŌS outcome scale on-device, surfaces the Just Mind blog, and
links to the IntakeQ client portal. **Every piece of user-generated data lives
exclusively on the device** via SwiftData — no remote sync, no analytics, no PHI
transmission.

## Build & run

This repository is a complete iOS app source tree organized for
[XcodeGen](https://github.com/yonaskolb/XcodeGen). XcodeGen turns the
`project.yml` spec into an `.xcodeproj` so the project is regenerable from
text and avoids checked-in pbxproj merge conflicts.

```bash
brew install xcodegen
cd "Claude Code - ios App for JMC"
xcodegen generate
open JustMind.xcodeproj
```

If you'd rather not use XcodeGen, you can also create a new "App" target in
Xcode (iOS 17, SwiftUI lifecycle, SwiftData), then drag the `JustMind/`
folder into it as a group reference. The asset catalog and Info.plist will be
picked up automatically.

**Minimum target:** iOS 17.0. **Tested-against simulator:** iPhone 15 Pro / iOS 17.

## Project layout

```
JustMind/
├── JustMindApp.swift              @main, SwiftData container wiring
├── Models/                        SwiftData models + UserDefaults
│   ├── MoodEntry.swift
│   ├── ROSEntry.swift
│   ├── JournalEntry.swift         Long-form journal + daily prompt rotation
│   ├── CachedPost.swift
│   └── UserPreferences.swift
├── DesignSystem/                  Adaptive colors, type, card / button styles
├── Services/                      Biometrics, blog API, newsletter, quotes
├── Views/
│   ├── RootView.swift             4-tab TabView + biometric lock + scene blur
│   ├── Onboarding/                3-card swipeable onboarding
│   ├── Home/                      Greeting, mood summary, quick actions, quote
│   ├── CheckIn/
│   │   ├── CheckInView.swift      Segmented Mood / RŌS host
│   │   ├── MoodView.swift         Emoji + note + tags + journal entry point
│   │   ├── MoodHistoryView.swift  Interleaved mood + journal log
│   │   ├── JournalEditorView.swift Long-form writing sheet, prompted
│   │   ├── ROSView.swift          4-item flow with VAS slider
│   │   ├── ROSResultsView.swift   ScoreArc + cutoff + RCI callout
│   │   ├── ROSHistoryView.swift   [Log] / [Trends] segmented control
│   │   ├── ROSTrendsView.swift    30 / 90 / 180-day window analysis
│   │   └── VASSlider.swift        Custom 0.0–10.0 visual analog scale
│   ├── Blog/                      WordPress fetch + sticky newsletter card
│   ├── MyCare/                    IntakeQ links + settings + About
│   └── Common/                    SafariView, privacy modifier
├── Resources/Info.plist
└── Assets.xcassets                Brand colors, AppIcon, LogoMark
```

## Privacy posture

| Surface                             | Storage                               |
|-------------------------------------|---------------------------------------|
| Preferred name, app lock, next appt | UserDefaults (on-device only)         |
| Mood entries (5 fields)             | SwiftData (on-device only)            |
| Journal entries                     | SwiftData (on-device only)            |
| RŌS entries (4 items + total)       | SwiftData (on-device only)            |
| Cached blog posts (public data)     | SwiftData (on-device only)            |
| Sleep data (HealthKit)              | Read-only from Apple Health; not persisted by the app |
| Newsletter email                    | Sent once to Just Mind, not retained  |

- No iCloud / CloudKit. The `ModelContainer` is created with a `ModelConfiguration`
  that explicitly does **not** opt into CloudKit syncing.
- No third-party analytics, crash reporting, or telemetry SDKs.
- `.privacySensitive()` (`jmPrivacySensitive()`) is applied to the Check-In tab
  and the Home mood card.
- App-switcher snapshot redaction is handled in `RootView`: when the scene
  becomes inactive and app lock is enabled, a blurred lock overlay is presented
  before the OS captures the snapshot.
- Face ID / Touch ID is gated through `LocalAuthentication`. Failed or cancelled
  auth keeps the app locked; an unavailable biometric (e.g. simulator without
  enrolment) gracefully disables the lock instead of trapping the user.
- "Clear All My Data" wipes every SwiftData store and every app-owned
  UserDefaults key in two taps.

## Things I had to decide differently from the spec

1. **Newsletter is Gravity Forms + Cloudflare Turnstile, not Mailchimp.**
   Inspecting `https://justmind.org` shows the footer signup is a Gravity Forms
   form (`gform_18`), not a Mailchimp embed. There is no `list-manage.com`
   action URL to extract; the action is `/` and the form requires a Cloudflare
   Turnstile token plus a per-page-load `state_18` token. A direct programmatic
   POST without solving the Turnstile challenge will be rejected.

   `NewsletterService.subscribe(email:)` does its best: it fetches the homepage
   to harvest the dynamic state tokens and POSTs a multipart submission. If
   the server response doesn't show a Gravity Forms confirmation marker, we
   surface a fallback in `NewsletterCard` that opens the website footer in
   `SFSafariViewController` so the user can complete the signup there. The
   submitted email is never persisted on-device regardless of which path
   succeeds.

2. **Topical filter chips wired to tags, not categories.** The spec maps chips
   like Anxiety / Depression / ADHD / LGBTQ+ to WordPress *categories*, but
   `https://justmind.org/wp-json/wp/v2/categories` returns only `Blog`,
   `Events`, and `Uncategorized`. The topical taxonomy lives in
   *tags* (`anxiety`, `depression`, `adhd`, `lgbt`, `parenting`, `growth`, …).
   `BlogService.curatedTagSlugs` maps each chip label to one or more tag
   slugs, and chips with zero matching posts are hidden — the spec's intent
   ("if a category returns 0 posts, hide that chip") is preserved. Swap to
   categories in `BlogService` if the site adds them later.

3. **Logo and app icon are placeholders.** The Just Mind brand SVG at
   `https://justmind.org/wp-content/uploads/2020/02/logo.svg` should replace
   `Assets.xcassets/LogoMark.imageset/logo-mark.svg`. The current
   `AppIcon-1024.png` is a generated sage placeholder — replace before
   shipping. The `LogoMark` is template-rendered, so it picks up the brand
   tint anywhere it's drawn.

4. **All three IntakeQ portal cards link to the portal root.** IntakeQ does
   not publish stable deep links for messages / invoices / payment method, so
   the portal handles internal routing after auth — same as the web flow.
   Update the URLs in `MyCareView.swift` if IntakeQ exposes them later.

## Design system

The visual language leans deliberately toward *subtraction*: hairlines instead
of shadows, restrained color, large but light-weight display type, and content
treated as the primary interface element. Cards group via 0.5pt borders rather
than elevation; numbers are weighted (`heroNumber` is `.ultraLight`) so they
read as considered rather than loud.

- **Palette:** soft sage / teal, warm whites, muted earth tones. All defined as
  adaptive light/dark color sets in `Assets.xcassets` (`BrandPrimary`,
  `BrandBackground`, `BrandSurface`, `BrandDivider`, etc.).
- **Type:** SF Pro (system) at semantic sizes — `JMFont.heroNumber` /
  `.display` / `.largeTitle` / `.title` / `.headline` / `.body` / `.callout` /
  `.footnote` / `.caption` / `.micro`. Display sizes are `.light` /
  `.ultraLight`, body type stays regular. `jmDisplayTracking()` tightens
  letter-spacing on display text. Dynamic Type scales naturally.
- **Surfaces:** 18pt rounded cards. The default is `.jmQuietCard()` —
  hairline border, no shadow. `.jmCard(elevated: true)` is the rare opt-in
  for items that genuinely deserve emphasis (e.g. a sticky session-prep
  reminder), and even there the shadow is faint.
- **Buttons:** four styles — `.jmPrimary` (filled sage), `.jmOutline`
  (hairline outlined peer), `.jmGhost` (borderless secondary), and
  `.jmSecondary` (compat alias mapped to outline).
- **Hairlines:** `JMHairline()` is a true 0.5pt rule used in lieu of dividers
  with weight, including between rows of grouped cards (Quick Actions,
  Settings, Portal links).
- **Tone:** the `QuoteService` rotation, onboarding copy, journal prompts, and
  result-screen messages were written to be warm and grounded, never clinical.

## Mood + Journaling

The mood section pairs a quick check-in with optional long-form writing.

- **Quick check-in:** 5-emoji selector (selected emoji grows and shows a 2pt
  underline rather than sitting in a tinted pill), an optional one-line note,
  up to 3 tags from a curated list, and a `Save Check-In` primary action.
- **Open Journal** (ghost button, immediately below Save): launches
  `JournalEditorView` — a full-screen writing surface with the date in
  uppercase tracked footnote, today's rotating writing prompt as the title,
  a hairline divider, and a generous editor pane. The toolbar shows live
  word count; saving requires non-empty text. Cancelling with unsaved
  changes raises a confirmation.
- **Linkage:** if the user just saved a mood entry and then opens the
  journal, the resulting `JournalEntry` is loosely linked to that mood by
  UUID (so a future session-prep view could surface "what you wrote that day"
  alongside the mood without coupling the schemas tightly).
- **History:** `MoodHistoryView` interleaves mood entries and journal entries
  in a single chronological list within the selected window (7d / 30d).
  Tapping a journal row reopens it in the editor for revision.
- **Prompts:** `JournalPrompts` provides 15 short, considered prompts that
  rotate by date seed. Users are free to ignore them.

## RŌS Trends

The RŌS history view now toggles between **Log** and **Trends** via a
segmented control.

- **Window selector:** 30 / 90 / 180 days.
- **Average total** as a hero number (`.ultraLight`, ~64pt) with a delta vs
  the prior comparable window (e.g. "+2.4 vs prior 90 days") tinted by
  direction (sage for up, warning for down, neutral when steady within
  ±0.05).
- **Stat row:** entries · % above the clinical cutoff · count of Reliable
  Change Index events (≥6-point shifts) within the window.
- **Trend chart:** total over the window with a dashed average line and a
  faint cutoff reference at 25.
- **Subscale breakdown:** a hairline-thin progress bar per subscale
  (Individual / Interpersonal / Social / Overall) showing the window-average
  on the 0–10 scale.
- **Comparison math** is computed locally from on-device entries — no data
  leaves the device. Edge cases handled: zero entries shows an empty state;
  one entry shows it but says "a second entry unlocks the trend"; no prior
  window shows "Not enough prior data for a comparison yet."

## RŌS implementation notes

- Each item is rendered on its own card; the user advances via `Next` (or
  `Back`). `VASSlider` is a fully custom continuous track with a circular
  handle, captured to one decimal at 0.0–10.0, default midpoint 5.0, with
  haptics on drag and `accessibilityAdjustable` for VoiceOver users.
- Results screen: `ScoreArc` draws a ¾-circle arc with a thin warning-toned
  cutoff tick at 25; total appears in the center.
- Reliable Change Index (RCI = 6) is computed against the previous saved
  entry; meaningful shifts surface a gentle callout on the results screen and
  appear as warning-toned dots on the history chart.
- The mandatory disclaimer about Seidel et al. (2016) is present at the
  bottom of every results screen.

## Apple Health Sleep

7-day rolling chart of sleep duration + a derived quality signal, surfaced in
two places.

- **Permissions:** read-only access to `HKCategoryTypeIdentifierSleepAnalysis`
  (and `HeartRateVariabilitySDNN` is requested but unused for now — reserved
  for a future quality refinement). Authorization is requested *the first time
  the user engages the feature* (tapping Connect on the home Sleep card or
  opening the Sleep tab) rather than at first launch — this respects the
  spec's plain-language explanation while not pre-prompting people who might
  not want sleep tracking. The exact disclosure copy: "Just Mind reads your
  sleep data so you and your therapist can see how rest affects your mood.
  The data stays on this device — Just Mind never uploads it."
- **Aggregation:** raw `HKCategorySample`s are bucketed by *wake-day* (so a
  session ending Tuesday morning belongs to Tuesday). For each of the last
  7 calendar days we fold samples into total asleep time, deep+REM time,
  earliest bedtime, and latest wake time. Empty days are kept as zero-height
  bars so the chart always shows seven slots.
- **Quality:** `(deep + REM) / total asleep` and total hours together produce
  a 3-bucket signal: **Good** (≥7h *or* ≥20% restorative), **Fair**
  (≥5.5h *or* ≥13% restorative), **Low**. Each bucket has its own adaptive
  color (`BrandSleepGood / Fair / Low` in the asset catalog) and a 3-dot
  indicator in the detail card.
- **Home card:** collapsed by default with one summary line —
  *"Avg 6h 42m · 4 of 7 nights logged."* Tapping expands to a 140pt mini-bar
  chart with the average reference line. When unauthorized, shows a soft
  Connect prompt instead.
- **Check-In tab:** a third segment alongside Mood and RŌS. Bars are tappable
  to surface that night's detail (bedtime, wake, duration, restorative %)
  inline, and a per-night list below the chart drills into the same detail.
- **Project setup:** HealthKit is wired in via `JustMind.entitlements`
  (referenced in `project.yml`) and `NSHealthShareUsageDescription` in
  `Info.plist`. The `HealthKit.framework` SDK dependency is declared so
  XcodeGen links it automatically.

## Design refinements (priority-order pass)

A second pass tightened the visual language and motion across the app, with
deliberate attention to the moments the app gets used in. Highlights:

1. **Capitalization** — preferred name is stored as-entered and rendered with
   `.capitalized` everywhere it appears (currently the home greeting), so a
   user typing "billy" still sees "Good morning, Billy."
2. **Haptics** — Save Check-In fires `.medium` impact (a single grounded
   "received" tap), Complete RŌS fires `.success` notification, mood-emoji
   selection fires `.light` impact, and tapping "Message my therapist" fires
   `.success` notification. Navigation, scrolling, and other passive
   interactions get nothing.
3. **Whitespace** — card vertical padding bumped to a 20pt minimum
   (`JMSpacing.cardV`), Home cards now sit on a 14pt gap
   (`JMSpacing.homeCardGap`), and there's a 28pt breathing space below the
   greeting before the first card.
4. **Typography hierarchy** — the home greeting is now `JMFont.greeting`
   (32pt / 700) and is the loudest element on the screen. Quick-action
   labels use `JMFont.bodyEmph` (17/500). Section sub-labels
   ("TODAY", "YOUR SLEEP THIS WEEK") are `JMFont.sectionLabel` (12/500)
   with 0.08em tracking and uppercase. Blog titles use `JMFont.blogTitle`
   (20/700) with 13pt muted bylines for a clear size step.
5. **Color discipline** — forest green (`JMColor.primary`) is now reserved
   for primary CTAs, the active nav-tab tint, RŌS step numerals, and
   secondary text actions. Decorative or passive icon foregrounds (Home
   quick actions, MyCare portal rows, onboarding feature rows) shifted to
   `textSecondary`. The home quote card lost its border and shadow; it
   sits flush on the background, leaf icon at muted sage opacity 0.55,
   italic 16pt body with 1.6 line-height.
6. **Motion** — Home cards stagger in on appearance (4pt translate up, 60ms
   between cards, 280ms ease-out). The Check-In segmented control
   cross-fades between Mood / RŌS / Sleep at 200ms (no slide — sliding
   reads as navigation, cross-fade reads as a perspective shift). The Save
   Check-In button briefly compresses to 0.97 scale, then the form
   cross-fades to a confirmation state with a "Continue in Journal" CTA
   instead of resetting to a toast. The home quote refreshes with a 600ms
   opacity transition when the daily seed changes.

## Out of scope (per the spec — explicitly **not** built)

- Push notifications
- Therapist / clinician dashboard
- iCloud or any remote sync
- Telehealth / video
- PHI transmission of any kind
- Analytics or crash reporting

## Files worth re-reading first

- `JustMind/Services/NewsletterService.swift` — Gravity Forms POST attempt
  with token harvesting, plus the Safari fallback contract.
- `JustMind/Services/BlogService.swift` — WordPress decoding (titles,
  excerpts, embedded media + author) and the curated tag map.
- `JustMind/Views/CheckIn/VASSlider.swift` — custom drag-driven 0.0–10.0
  visual analog scale with VoiceOver support.
- `JustMind/Views/RootView.swift` — onboarding gate, biometric lock,
  scene-phase blur, and tab routing.
