# RelayContent UI implementation status

Updated: 8 September 2026

This tracker measures the complete Flutter UI and local/mock interactions for the approved mobile prototype. TikTok/provider APIs, real camera capture, media rendering, and server persistence are integration work outside this percentage.

## Current UI/local mock status: 100%

| Area | Status | Completed prototype behavior |
|---|---:|---|
| Visual system | 100% | Mobile dark theme, Thai typography, semantic colors, reusable surfaces, responsive controls, product photography, status overlays, shimmer loading, reduced-motion support and consistent bottom navigation |
| Entry and auth | 100% | Login, registration, validation, session restore, local password recovery, password guidance and three-step onboarding |
| Main navigation | 100% | Persistent five-tab indexed shell; each tab preserves its stack and state, and tapping the active tab returns to its root |
| Home | 100% | Relay-first empty and active dashboards, contextual greeting, notification badge, actionable job groups, all-clear state, error recovery links and direct content-detail navigation; sign-out exists only in Profile |
| Showcase/products | 100% | Search, filters, empty state, stock and commission states, product detail with a linked-content panel (clip count, estimated revenue, jump to each clip), shared saved-product state, product selection and generated product imagery |
| AI source relay | 100% | Provider connection states, capability warnings, share/import entry, progress, success, failure, retry, dismiss, multi-select deletion, media cards, full-screen preview and product handoff |
| In-app AI creation (secondary) | 100% | Product brief, concept and tone controls, editable script, voice and subtitle choices, generation progress, safe cancellation, three variants, safety checks and approval |
| Upload creation | 100% | File picking, upload progress, preview/fallback, replace, trim, thumbnail selection, caption editing and handoff to the shared basket review |
| Guided filming | 100% | Product-aware three-shot guide, composition grid, coaching, multiple takes, take selection, retained progress when going back, guarded take deletion and review handoff |
| Basket and publishing | 100% | All creation paths converge on one review with source/media/caption context, full-screen preview, guarded basket removal, caption/tags, schedule controls, a 100-point content readiness score with jump-to-fix and a non-blocking low-score confirm, checklist, submission progress and accepted state |
| Content management | 100% | Lifecycle filters, status visuals, action sheets, detail timeline, metrics, retry, rescheduling, guarded cancellation and restore-to-schedule state |
| Profile/connections | 100% | Editable local creator identity, TikTok and AI-source entry points, notification settings, theme, reduced motion, timezone, help/privacy details and confirmed sign-out |

## Prototype acceptance flow

1. Sign in or complete registration and onboarding.
2. Import content from AI Content Inbox, generate a draft in the app, upload a clip, or record guided takes.
3. Choose a Showcase product and carry it through the creation flow.
4. Preview the media, edit the caption, verify the product basket, and choose publish now or schedule.
5. Submit to the local queue and inspect, retry, reschedule, cancel, or restore work from Content.
6. Change local app preferences and sign out from Profile.

## Integration work after UX approval

- TikTok Shop catalog, basket, OAuth, creator info and publishing endpoints.
- External AI provider OAuth/share extensions and resumable media imports.
- Real camera permissions, recording, clip stitching and device recovery.
- Real media transcoding, thumbnail extraction, trimming, playback and AI rendering.
- Backend persistence for onboarding, preferences, saved products and content edits.
- A content repository replacing the in-memory `ContentStore` that now backs Home, Content and publishing from one source.
- Production account recovery email, verification, legal and support content.

These items replace the current local fixtures and simulated progress without changing the approved screen flow.