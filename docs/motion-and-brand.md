# Brand and motion update

The supplied business card is the visual reference for the silver/cyan/blue L, orbital swoosh, cyan pixels and LUTERA TECHNOLOGIES LTD wordmark. Full-resolution transparent artwork and a 42 KB WebP derivative are in assets. Header, footer, favicon and social artwork use the updated identity.

The homepage scene uses real Three.js geometry for the laptop, keyboard, server, switch, antennae and orbital connection packets. Pointer position changes the view. Pause/resume stops the scene and hero CSS animation. The scene caps at approximately 30 frames per second, limits pixel ratio and suspends when offscreen or the browser tab is hidden.

Initial content is independent of WebGL. 3D starts automatically on desktop and large-tablet layouts at least 1024 CSS pixels wide. Tablet layouts at least 768 pixels wide also qualify when a mouse/trackpad is present or trusted Tab-key navigation signals keyboard use. Physical keyboard attachment itself has no reliable browser API. Phone user agents, small touch-only tablet layouts, reduced-motion and data-saver visits retain the illustration. Touch gestures keep normal vertical scrolling; a swipe does not select a device. Changing motion preferences or viewport settings disposes/remounts the canvas as appropriate.

Other motion includes hero text entrance, restrained gradient/orbit movement, staggered scroll reveals, card tilt, procurement scan highlights and native cross-document fades where supported. Content remains available without JavaScript. Reduced-motion removes entrance, transform, scanning and route animations. The mobile illustration remains static.

Verification: browser checks passed for actual moving WebGL geometry, pause/resume, pointer interaction, scroll reveals, hover tilt, dynamic reduced-motion, no-WebGL fallback, mobile navigation and preserved email form settings. Static checks validate links, assets, headings, IDs, alt attributes and JavaScript syntax. Fonts are self-hosted under their OFL licenses; Three.js 0.180.0 is pinned and self-hosted under MIT.

Performance: no field Core Web Vitals claims are made. Constrained 4x CPU / 1.6 Mbps software-browser lab runs varied and did not consistently achieve the blueprint's 2.5-second LCP goal. Measured layout shift remained below 0.03 in those runs. Desktop scene startup is automatic; mobile and reduced-motion visits load no 3D library. Production field measurements are still needed to establish p75 LCP, CLS and INP.

The existing email-only FormSubmit workflow is preserved. No new database, accounts or purchase flow is introduced.

## Cinematic navigation and the project story

`assets/cinematic.js` and `assets/cinematic.css` add a camera-like transition between same-origin pages. Browsers with cross-document View Transitions use native snapshots with a perspective/dolly effect while the header and floating contact control stay anchored. Browsers without that feature get a brief 220 ms outgoing curtain and a 500 ms reveal. Links retain their real destinations: forms, downloads, external links, anchors, modified clicks and browser back/forward keep their normal behavior. Page restoration clears outgoing state.

The homepage introduces a four-chapter project story: Discover, Design, Build & Connect, and Launch & Support. Native scrolling moves a CSS 3D assembly with a central LUTERA mark, connected modules and progress indicator. Chapter links jump directly to the corresponding text. The scene holds within that section on desktop; it releases at the end. No wheel/touch event hijacking, video, animation framework or extra WebGL canvas is required. Updates run once per scroll/resize frame, with no independent animation loop.

Large screens and qualifying keyboard/trackpad tablets share the story's desktop scene policy. Phones and small touch-only tablets get a compact static illustration and ordinary reading layout. Reduced-motion disables native route animation, the curtain, the pinned scene and camera transforms. A scene pause control holds its current pose while text and links remain available. Data-saver visits skip cinematic motion. All four chapters and quote links remain available with JavaScript disabled.

`python tests/browser_cinematic.py` checks scroll-driven pose changes, sticky behavior, pause/resume, live reduced-motion changes, successful native snapshot capture, fallback navigation, browser back restoration, chapter anchors, quote-list preservation and mobile/no-JavaScript alternatives. Existing procurement and real-WebGL tablet tests remain in CI. Form submissions in the procurement tests are intercepted and send no email.
