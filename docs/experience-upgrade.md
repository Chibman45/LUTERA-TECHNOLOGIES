# Procurement experience upgrade — additions 1–10

1. **Interactive equipment explorer:** projected keyboard-accessible hotspots on the 3D laptop, server and network switch, mesh picking, a detail popup and solution-to-quote actions. Semantic equipment tabs provide the same information without WebGL.
2. **Guided quote:** three stages (needs, specifications, contact/review), field validation, future-date checks, preserved answers when stepping back, accessible progress and an email summary.
3. **Enquiry list:** add equipment, change quantities, remove items, clear or copy the list and continue across pages. Only known equipment IDs, quantities and a predefined business-need ID enter tab-scoped session storage. Contact information and free-text answers are never saved there. A URL fallback carries the list when browser storage is blocked.
4. **Distinctive layouts:** asymmetric service panels, a large procurement feature and equipment photography cards replace repetitive homepage card sections.
5. **Brand graphics:** orbit diagrams, connection paths, cyan pixels, photographic edge accents and consistent equipment icons extend the name-card identity.
6. **Business-need navigation:** new office, equipment refresh, remote team and infrastructure-upgrade links prefill a relevant procurement brief.
7. **Equipment comparison:** laptop, desktop/all-in-one and workstation comparison with two or three selectable columns and add-to-enquiry actions. The guidance does not claim model availability or fixed pricing.
8. **Procurement timeline:** four keyboard-accessible stages with context and preparation checklists, on the homepage and procurement page.
9. **Equipment photography:** locally served Unsplash equipment/workplace imagery, consistent styling, representative-image notices and source/license records in photo-credits.md.
10. **Mobile actions:** safe-area-aware quote and WhatsApp controls, hidden on active quote/contact pages so forms remain unobstructed. Desktop and eligible large/keyboard/trackpad tablets use automatic 3D; phones and small touch-only tablets retain the illustration.

## Delivery and privacy

RFQs and contact messages remain native HTTPS POSTs to FormSubmit for delivery to chimaster010@gmail.com. Equipment lines, quantities, project context, form fields and privacy acknowledgement timestamp are included. Provider spam checks and recipient activation remain external. No database, public accounts, checkout, marketing tracking or price estimates have been added. Browser duplicate-click guards do not promise provider-side idempotency. The privacy and cookie pages describe the new functional session storage.

## Verification

`tests/browser_experience.py` hosts the built static site itself unless LUTERA_TEST_URL is supplied. It checks equipment selection, tab keyboard behavior, timeline stages, list persistence and quantity edits, comparison controls, guided validation/back navigation, structured form payloads, contact transport, responsive layouts at 360/768/1024/1440 pixels, native no-JavaScript RFQ rendering and storage-blocked fallback. External form requests are intercepted; these tests send no email. It is run in GitHub Actions using pinned Playwright dependencies.

A separate WebGL browser check verified automatic scene rendering, projected hotspot positions, keyboard activation of all three devices and a server-to-quote handoff. Image checks decoded the lazy-loaded local photographs after scrolling. Static checks cover links, assets, headings, IDs, alternative text and script syntax.

`tests/browser_tablet_3d.py` additionally checks real WebGL on large touch tablets, 1024px tablets and smaller trackpad/keyboard tablets, along with phone/small-tablet/reduced-motion fallbacks and swipe protection.
