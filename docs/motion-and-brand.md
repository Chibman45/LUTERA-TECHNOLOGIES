# Brand and motion update

The supplied business card is the visual reference for the silver/cyan/blue L, orbital swoosh, cyan pixels and LUTERA TECHNOLOGIES LTD wordmark. Full-resolution transparent artwork and a 42 KB WebP derivative are in assets. Header, footer, favicon and social artwork use the updated identity.

The homepage scene uses real Three.js geometry for the laptop, keyboard, server, switch, antennae and orbital connection packets. Pointer position changes the view. Pause/resume stops the scene and hero CSS animation. The scene caps at approximately 30 frames per second, limits pixel ratio and suspends when offscreen or the browser tab is hidden.

Initial content is independent of WebGL. 3D starts automatically on desktop and large-tablet layouts at least 1024 CSS pixels wide. Tablet layouts at least 768 pixels wide also qualify when a mouse/trackpad is present or trusted Tab-key navigation signals keyboard use. Physical keyboard attachment itself has no reliable browser API. Phone user agents, small touch-only tablet layouts, reduced-motion and data-saver visits retain the illustration. Touch gestures keep normal vertical scrolling; a swipe does not select a device. Changing motion preferences or viewport settings disposes/remounts the canvas as appropriate.

Other motion includes hero text entrance, restrained gradient/orbit movement, staggered scroll reveals, card tilt, procurement scan highlights and native cross-document fades where supported. Content remains available without JavaScript. Reduced-motion removes entrance, transform, scanning and route animations. The mobile illustration remains static.

Verification: browser checks passed for actual moving WebGL geometry, pause/resume, pointer interaction, scroll reveals, hover tilt, dynamic reduced-motion, no-WebGL fallback, mobile navigation and preserved email form settings. Static checks validate links, assets, headings, IDs, alt attributes and JavaScript syntax. Fonts are self-hosted under their OFL licenses; Three.js 0.180.0 is pinned and self-hosted under MIT.

Performance: no field Core Web Vitals claims are made. Constrained 4x CPU / 1.6 Mbps software-browser lab runs varied and did not consistently achieve the blueprint's 2.5-second LCP goal. Measured layout shift remained below 0.03 in those runs. Desktop scene startup is automatic; mobile and reduced-motion visits load no 3D library. Production field measurements are still needed to establish p75 LCP, CLS and INP.

The existing email-only FormSubmit workflow is preserved. No new database, accounts or purchase flow is introduced.
