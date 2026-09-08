# RelayContent UI implementation status

Updated: 8 September 2026

This tracker measures the Flutter UI and local/mock interactions only. TikTok API availability is intentionally excluded.

## Current overall status: 87%

| Area | Status | Implemented now | Main gap |
|---|---:|---|---|
| Visual system | 82% | Dark palette, Thai font, surfaces, buttons, chips, navigation styling, generated product photography, reusable product artwork with Hero continuity and shimmer skeleton loaders (Home, Content) that honour reduced-motion | Shared media thumbnails and broader motion language |
| Entry and auth | 82% | Session restore, login/register UI, password guidance, validation, local forgot-password recovery and three-step post-registration onboarding | Real recovery email endpoint, onboarding persistence and account verification |
| Main navigation | 80% | Persistent five-tab shell for Home, Showcase, Create, Content, Profile | Preserve tab stacks and deep-link state |
| Home | 88% | New-user state, active groups, all-clear summary, actionable errors, notification deep links, visual job cards and direct job-detail navigation | Trend insights and personalized recommendations |
| Showcase/products | 80% | Search, filters, empty state, stock/commission cards, generated product imagery, saved-product interactions, product detail and product selection using local fixtures | Persist saved products and add richer pricing/media states |
| AI source relay | 55% | AI Content Inbox, connected-source states, Share/import guidance, mock sync progress, content selection and product handoff | Real OAuth/share extension, provider capability checks, background imports and recovery |
| In-app AI creation (secondary) | 70% | Product brief, concepts, duration, tone, editable script, voice, subtitles, generation motion, three variants, safety checks and approval | Real media rendering, full timeline editor and recovery |
| Upload creation | 82% | Selected-product requirement, pick, upload progress, preview, file summary, replace/trim interactions, caption and handoff into the shared basket review | Apply trim to the media file, thumbnail selection and upload recovery details |
| Guided filming | 70% | Product-aware three-shot guide, composition grid, coaching tips, multiple local takes, take selection and handoff into shared basket review | Real camera recording, permissions, clip stitching and device recovery |
| Basket and publishing | 92% | AI/import/upload paths converge on one review; source, media and caption carry through; large visual preview, full-height playback sheet, destination summary, guarded basket removal, live caption/tag preview, suggested slots, date/time pickers, final checklist, submission progress and accepted state use local state | Real media playback, multi-platform review, retry details and real submission |
| Content management | 82% | Lifecycle filters, demo states, shared visual thumbnails, status overlays, contextual action sheets, direct detail navigation, progress timeline, metrics and local retry actions | Persistent edits, cancel/reschedule confirmation, real permalink and backend recovery |
| Profile/connections | 88% | Editable local creator identity, TikTok and AI-source entry points, notification settings, live app theme and reduced-motion controls, timezone selection, in-app help/privacy details and confirmed sign-out | Persist preferences, backend account update and production legal/support content |

## Why the app still feels generic

- Several pages are standard forms placed on a dark background.
- Product and video identity disappear in parts of the flow.
- Content-job thumbnails currently reuse product artwork until real imported/rendered media is available.
- Guided filming interactions simulate takes until real camera permissions and recording are implemented.
- Generation uses a convincing local preview; it does not render real media yet.
- Few controls demonstrate useful local interactions beyond validation and navigation.
- Loading states now use shimmer skeletons on Home and Content; other lists still fall back to a plain spinner.
- Empty, success, and recovery states are uneven across features.

## Mock-first implementation order

1. ~~Showcase search/filter → Product Detail → selected product carried into Create.~~
2. ~~AI Content Inbox → source connection/share → content selection → product handoff.~~
3. ~~Secondary in-app AI creation → brief → script → generation → variant review → approval.~~
4. ~~Upload flow converges with imported content at Caption & Product.~~
5. ~~Basket verification → post/schedule → date/time → final review → accepted/success.~~
6. ~~Content Library detail and recovery states.~~
7. ~~Notifications and Profile UI/local preferences.~~

Each phase must be usable with local fixtures before any TikTok endpoint is connected.
