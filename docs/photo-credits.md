# Solution and equipment imagery

Representative solution, equipment and workplace images are sourced from Unsplash, for use under the [Unsplash License](https://unsplash.com/license). They are illustrative imagery, not photographs of Lutera stock, offices or completed projects. No manufacturer partnership is asserted.

- `assets/photos/laptop.jpg`: https://images.unsplash.com/photo-1496181133206-80ce9b88a853
- `assets/photos/workplace.jpg`: https://images.unsplash.com/photo-1498050108023-c5249f4df085
- `assets/photos/servers.jpg`: https://images.unsplash.com/photo-1558494949-ef010cbdcc31

Original local copies use Unsplash’s image-sizing output (1100px width, quality 82). New solution images use 960 × 640 output, quality 82. The website does not call the Unsplash API or request remote photos at runtime.

Solution-specific images added to match the expanded business scope:

- `assets/photos/ai.jpg`: https://images.unsplash.com/photo-1552664730-d307ca884978 — team mapping a business workflow.
- `assets/photos/software.jpg`: https://images.unsplash.com/photo-1555066931-4365d14bab8c — software source code.
- `assets/photos/data.jpg`: https://images.unsplash.com/photo-1551288049-bebda4e38f71 — analytics dashboard.
- `assets/photos/network.jpg`: https://images.unsplash.com/photo-1544197150-b99a580bb7a8 — network patch panel.
- `assets/photos/consulting.jpg`: https://images.unsplash.com/photo-1522071820081-009f0129c71c — team discussing requirements with laptops.
- `assets/photos/support.jpg`: https://images.unsplash.com/photo-1581092918056-0c4c3acd3789 — technician installing memory in computer equipment.
- `assets/photos/printer.jpg`: https://images.unsplash.com/photo-1612815154858-60aa4c59eaa6 — multifunction printer.
- `assets/photos/accessory.jpg`: https://images.unsplash.com/photo-1587829741301-dc798b83add3 — computer keyboard.
- `assets/photos/desktop.jpg`: https://images.unsplash.com/photo-1547082299-de196ea013d6 — desktop computer setup.
- `assets/photos/procurement.jpg`: https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d — warehouse and supply context.

Cloud and integration use the existing server-rack image. Network, printer, desktop and accessory categories now use subject-specific images instead of repeated generic laptop/workplace pictures. These are illustrations of the service categories, not Lutera staff, premises, inventory or client work.

The October 2026 rebrand replaces the conceptual AI art with workflow photography and the support circuit-board image with actual computer maintenance. Procurement uses the laptop specification photograph; the warehouse photograph is retained as an unused source asset. All final page images are served locally.

Responsive 480px and 960px WebP versions are generated from the local source files by `scripts/prepare_images.py`. The HTML includes `srcset` and `sizes` so smaller screens can request a smaller image. Original JPEG source files are retained.

## Photographic hero update

The homepage rotates three representative technology scenes, with a consistent dark overlay and readable white text. These photographs do not depict Lutera staff, premises or completed work.

- `hero-workplace-{768,1280,1920}.webp`: https://images.unsplash.com/photo-1498050108023-c5249f4df085 — software development and a computing workspace.
- `hero-support-{768,1280,1920}.webp`: https://images.unsplash.com/photo-1581092918056-0c4c3acd3789 — computer hardware installation and support.
- `hero-cloud-{768,1280,1920}.webp`: https://images.unsplash.com/photo-1558494949-ef010cbdcc31 — connected server infrastructure.

Hero images use 1920 × 1200 source crops with local responsive WebP derivatives. Only the first image is requested initially; subsequent images load before their first transition. Reduced-motion and data-saving visits do not autoplay or preload the other backgrounds. With JavaScript disabled, the first image and all hero copy/actions remain available.
