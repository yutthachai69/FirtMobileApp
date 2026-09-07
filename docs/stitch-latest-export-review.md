# RelayContent — Stitch latest export review

Reviewed: 7 September 2026

## What was exported

Two folders are present:

- `stitch_relaycontent_mobile_ux_review1` contains 18 HTML screens and 17 PNG previews. The latest nine screens are a condensed happy-path prototype: dashboard, Showcase, product detail, four creation/publishing screens, content library, and published-job detail.
- `stitch_relaycontent_mobile_ux_review` contains only `calm_commerce_control_room/DESIGN.md`. It is not a screen export.

The latest nine screens do **not** implement Batch 2 from `docs/stitch-ux-prompt-v1.md`. Batch 2 requires B05, C01–C04, and D01–D04, including new-user, all-clear, notifications, connection failure, unavailable-product, and empty-Showcase states.

## Decision

Keep the files as visual exploration, but do not treat this export as an approved UX specification or start implementing it in Flutter yet.

## What works

- The dark visual direction is distinctive and much stronger than the current login-only visual language.
- The five-tab navigation matches the agreed structure: Home, Products, Create, Content, Profile.
- Products remain visible through Showcase, creation, preview, basket attachment, and published content.
- Human approval appears before publishing.
- The library and product cards are image-led and suited to mobile commerce.

## Blocking issues

1. **Wrong batch and missing states.** The output skips the nine requested Batch 2 screens and jumps across later flows. Recovery, empty, notification, scheduling, and first-use states are missing.
2. **Inconsistent artboards.** New PNGs use several dimensions: `552×1600`, `606×1600`, `574×1600`, `522×1600`, and `517×1600`, while other screens use `390×844`. Comparisons and implementation measurements are unreliable.
3. **The interface is too technical for creators.** Labels such as `SYNC: LIVE`, `AUTO_CADENCE`, `PIPELINE::DISPATCHED`, `Telemetry & Execution Pipeline Log`, latency, HTTP codes, API scopes, and mixed Thai/English dominate the product experience.
4. **Incorrect product model.** “เผยแพร่อัตโนมัติลง Showcase” implies videos publish into Showcase. Showcase supplies the affiliate product; the shoppable video is published to TikTok with that product basket attached.
5. **Unsupported automation language.** “Auto-Affiliate Tagging” and automatic basket language imply capabilities that have not been established. The creator must explicitly select and verify the product basket before approval.
6. **Unsafe content-truth example.** The preview claims visible results in seven days while the safety card says the content passes with 100%. The product-truth check must flag unsupported outcome/time claims rather than certify them.
7. **Latest Design System regresses the brief.** The separate `DESIGN.md` refers to creators, operators, multi-channel merchants, API credentials, telemetry, nodes, and high-stakes deployment. RelayContent V1 is for Thai TikTok Shop affiliate creators and should use familiar creator language.
8. **A01 still lacks `screen.png`.** Only its HTML exists.

## Paste this into Stitch next

```text
Revise the RelayContent project. Preserve all existing screens, but create the missing Batch 2 as exactly 9 NEW, separate 390 × 844 mobile artboards named exactly:

B05 Connection Problem
C01 Home — New User
C02 Home — Active
C03 Home — All Clear
C04 Notifications
D01 My Showcase
D02 Product Detail
D03 Product Unavailable
D04 Showcase Empty

Use the existing five-tab navigation: หน้าหลัก, สินค้า, สร้าง, คอนเทนต์, โปรไฟล์.

Product truth:
- RelayContent is a mobile app for Thai TikTok Shop Affiliate Creators.
- Showcase is the creator's product catalog imported from TikTok Shop.
- A creator selects a Showcase product, creates or uploads a video, reviews the content, explicitly confirms the product basket, then posts or schedules the shoppable video to TikTok.
- Never say a video is published “to Showcase”.
- Do not invent automatic affiliate tagging, automatic basket selection, seller tools, multi-channel tools, API credential screens, or unsupported partner status.

Language and hierarchy:
- Use natural Thai creator language first.
- Remove telemetry, pipeline logs, latency, HTTP codes, node names, internal job IDs, API scopes, AUTO_CADENCE, SYNC:LIVE, and English section names from normal user screens.
- Keep technical details only inside a later optional diagnostic view; do not add that view in this batch.
- Use one primary action per screen and minimum 44 px touch targets.
- Keep each artboard at exactly 390 × 844 and make content fit without presenting a full-page 1600 px capture as the artboard.

Screen requirements:
- B05: expired TikTok Creator connection; say drafts and schedules are safe; primary action เชื่อมต่อใหม่.
- C01: first-use home with clear steps and primary action สร้างคลิปแรก.
- C02: creator control room grouped into ต้องทำ, กำลังสร้าง, รอตรวจ, ตั้งเวลาไว้, โพสต์แล้ววันนี้; every content card shows its linked product.
- C03: calm all-clear state, next scheduled shoppable video, and simple weekly results.
- C04: actionable notifications for AI ready, reconnect required, product unavailable, publish success, and publish failure.
- D01: searchable and filterable Showcase with product image, current price, commission, stock, eligibility, and สร้างคอนเทนต์.
- D02: product gallery, current price/discount, stock, commission, shop, last synced time, verified selling points, and สร้างคอนเทนต์จากสินค้านี้.
- D03: out-of-stock or removed product; preserve linked drafts; actions เปลี่ยนสินค้า and ตรวจสอบอีกครั้ง.
- D04: explain how to add products to TikTok Showcase; action เปิด TikTok.

For any product/content safety example, flag unsupported claims such as guaranteed results or fixed outcome timelines. Do not show “PASS 100%” when such a claim is present.

Also export the missing A01 Splash `screen.png` at 390 × 844.
```

## Folder handling

Do not delete either folder until the next export is verified. Use `stitch_relaycontent_mobile_ux_review1` as the current screen archive. The separate `stitch_relaycontent_mobile_ux_review` folder can be removed after any useful design-system changes are reconciled; its current `DESIGN.md` should not replace the earlier one wholesale.
