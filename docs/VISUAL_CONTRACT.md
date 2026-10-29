# VISUAL CONTRACT — محمد استایل (LOCKED v1)

## Status
- **APPROVED visual direction**: dark cinematic luxury; black/charcoal, champagne gold accents, authentic barbershop imagery, sophisticated RTL typography.
- These references are **binding design targets**, not generic inspiration. No unapproved redesigns, pastel palettes, neon palettes, generic dashboards, floating decorative blobs, or interchangeable AI stock photos.
- **NOT approved as literal pixel assets**: AI-generated collage panels. All interactive elements MUST be implemented in HTML/CSS/React; never paste an entire screenshot or the crop as the webpage background.

## Screen-to-reference mapping (use references in `screen-references/`)
1. Homepage hero: `01-homepage-hero.png` — full-width cinematic photo on one side, readable large Persian headline on the other, crisp dark overlay, restrained CTA duo, elegant transparent nav.
2. Services: `02-services-grid.png` — six tall photographic/graphic cards with readable titles and subtle gold borders; NOT a standard SaaS icon dashboard. Service labels only from business source of truth.
3. Gallery: `03-before-after-gallery.png` — strong authentic photography, curated grids, optional before/after slider; no fabricated results. Real customer photos require consent.
4. Branch choice: `04-branches.png` — visually rich two-branch cards. Only branch A details known; branch B name/address/photo NOT VERIFIED: render placeholder only or hide from public until approved.
5. Booking: `05-booking-stepper.png` — elegant right-to-left stepper, high-contrast service selector, date/time picker, single clear primary action, price/deposit policy only when loaded from configured backend.
6. Admin: `06-admin-calendar.png` — practical dense calendar/metrics using a restrained gold accent. Admin is a separate layout; marketing visual effects should not compromise operational clarity.

## Design principles
- Real photos from `client-images/` are content. Use non-destructive visual treatments (dark gradient, crop, contrast) without changing faces/identities, ideally preserve aspect ratio via `object-fit:cover`.
- The AI concept art contains potentially implausible images/text; translate these into a **real functional UI**, not artifacts or garbled labels.
- Text is selectable/accessibility-readable; never bake menu labels, button text or form controls into raster images.
- Marketing layouts may be cinematic; booking/payment flows prioritize legibility, clear form states and keyboard usability.
- RTL is first-class, including nav, icon direction, stepper, grids, calendar and form labels.
- Responsive design targets: 1440×900 desktop, 1024×768 tablet, 390×844 mobile, and 375×812 mobile. No horizontal overflow.
- Desktop site uses a coherent content grid and generous whitespace; admin may use tighter spacing.
- Use tokens from `design-system/tokens.css` as a starting point; compare to reference and tune deliberately, not arbitrarily.
- Avoid anti-patterns: too many shadows/glows, unreadable tiny text, repeating generic portrait stock, uniformly identical card layouts, random unrelated icons.

## Strict content restrictions
- Brand: `محمد استایل`, brochure title `سالن ممتاز پونک`.
- Known public branch: `پونک، ساختمان رونیکا پالاس، لابی`.
- Instagram: `@mohammadstyle1`.
- The business has 2 branches, but exact second branch information is UNVERIFIED. Do not pretend both are in Poonak or invent its address.
- 6 brochure services: `استایل دامادی`, `هیرکات مو`, `فیشیال صورت`, `ماساژ`, `مانیکور`, `پدیکور`.
- No fabricated prices, durations, deposits, staff names, review scores, testimonials, booking availability, branch addresses, number of satisfied customers or booking performance metrics.
- Before/After content may be shown as portfolio examples for owner review; public publishing requires customer consent.

## Visual changes policy
A Codex implementation fails review if it replaces this reference style with its own aesthetic, renders a static screenshot as UI, invents business information, or delivers desktop-only pages. All proposed departures must be documented, approved and then reflected in this contract.

## Owner-authorized service imagery amendment — 2026-10-28

The owner explicitly requested generating relevant photographs for the remaining services: فیشیال صورت، ماساژ، مانیکور، پدیکور. These four service-card illustrations may therefore use newly generated photographic concepts matching the locked charcoal/champagne treatment. They must be visibly labeled as conceptual, have accurate alt text and provenance, and must not be represented as real clients, real salon equipment/interiors, Before/After results or staff. Keep generated illustrations out of the authentic portfolio gallery. Existing client-photo consent restrictions and the Phase 1 owner visual-approval gate remain in force.

The owner also identified the person in `groom-look.webp` as the barber: label that asset as the barber's portrait, not a customer grooming result or groom-service sample. No staff name or credentials are inferred.
