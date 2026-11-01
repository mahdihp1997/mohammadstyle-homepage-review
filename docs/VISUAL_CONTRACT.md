# VISUAL CONTRACT — محمد استایل (LOCKED v1)

## Owner reaffirmed the product visual baseline — 2026-11-01

Owner instruction: «همین ظاهر قبلی با عکس‌ها و قبل‌وبعد رو نگه دار، امکانات جدید رزرو و پنل مدیریت هم روی همین نسخه باشه. دیگه ظاهر تأییدشده رو تغییر نده.»

The restored private Homepage at b8853e9231f8610a6d7f171ff801a0adc258bdeb is the visual baseline. Preserve photographs, before/after interaction, gallery/filters, service imagery, fonts, image crops, spacing, branding and dark/champagne styling. New Booking, accounts and admin remain integrated with this version. Functional fixes retain this appearance; a redesign requires an explicit new owner request.

The sanitized public review must not replace the private product preview. Internal four-size reference captures at local outputs/product-final-review/restored-private-homepage contain private client photos and stay outside Git/public packages. This instruction does not grant public photo/font rights or deployment approval. Existing rights and production protections remain in force.

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

## Owner-authorized Phase 02 amendment — 2026-10-29

The current user request identifies the existing internal Homepage as the approved baseline and authorizes only a dedicated five-step `/booking` frontend. Preserve the Homepage and locked visual language. Explicitly labeled fictional fixtures may demonstrate staff eligibility, appointment times, hypothetical prices/durations and policy arithmetic; they are not confirmed business data. Defaults must show unknown real values. No real appointments, policy enforcement, financial transactions, APIs, database or messaging. Existing private image/font restrictions remain. Stop for owner visual and technical review after Phase 02; do not merge or push internal history/assets to the public review export.


## Owner supplied logo amendment — 2026-10-31

The owner explicitly requested the supplied Mohammad Style identity board as the site logo. Use the isolated gold MS/hair/beard monogram beside the existing live brand text in header, footer, Booking, admin and portfolio, and as browser/Apple icons. This authorizes replacing the prior decorative crown brand mark only; preserve the approved layouts, typography, business facts and operational behavior. Do not infer the board badge's EST 2024 or other decorative statements as verified business facts. See BRAND_LOGO.md and data/brand-logo-provenance.json.


## Owner requested local manual login — 2026-10-31

The owner authorized a manual administrator login in an independently chosen browser for the current isolated development environment. /admin/login reuses the existing logo, typography, charcoal/champagne palette and accessible RTL controls. This authorizes the local review credential/session entry only; it does not approve production identity/authentication bypass, new commercial data or changes to Homepage/Booking. See backend/mvp-integration/LOCAL_REVIEW_LOGIN.md.

## Owner-requested product refinements — 2026-11-01

The owner explicitly requested the two supplied IMG_2779/2781 photos, a one-line “فراتر از یک آرایشگاه” hero phrase, manual photo choices pending a future background video, varied craft imagery, a larger Instagram-gradient CTA, removal of visible “تصویر مفهومی”/“ارسالی کارفرما” and prototype presentation labels, mobile-friendly Before/After with clipped endpoint labels, About/Contact/Barbers pages, decorative salon tools, a split login and an optional persistent light admin theme. These are authorized amendments to the photographic baseline; preserve all other layouts, six services, facts and Booking/authentication behavior. Generated service illustrations remain documented accurately in alt text and provenance and never become authentic portfolio results. Private original/derivative photos remain development-gated and excluded from public review/production packages. No staff names, credentials, phone or opening hours are supplied; do not invent them. No video has yet been supplied; the media component supports an optional approved source, reduced motion and pause, with real photos as the current fallback. Automatic customer OTP filling is an explicit, default-off isolated development/mock-SMS option, never production authentication.

## Confirmed owner media and facts — 2026-11-01, later clarification

The owner supplied two actual films and confirmed the unit (thousands of Toman) and photo-to-staff mapping. `IMG_2803/2804` depict Amir; `IMG_2805/2806` depict Mohammad. These are alternative portraits, never hair Before/After pairs. Mohammad/Amir contact numbers and three provider-specific haircut rates are recorded in `data/business-facts.json`; Amirhossein has no supplied portrait or phone. The four care prices and the massage's 60-minute duration are confirmed; the groom package remains consultation-only. Do not infer qualifications, service duration, staff branch assignment, working hours, deposit or refund rules from this update.

Owner-authorized visual amendment: the closer work film becomes a short muted/blurred hero loop, the wider salon film a separate About chapter with text overlay; full original-length optimized films are available with native controls in the internal gallery. Posters, explicit pause, offscreen/tab pause, reduced-motion and save-data behavior are required. All originals are preserved unchanged; metadata-stripped derivatives remain internal review assets. This supersedes the earlier 'no video/staff data supplied' notes. Publication rights are still unconfirmed; none of these photos, movies, posters or screenshots may enter the public export or deployment package.

## Later owner corrections — 2026-11-02

This supersedes the hero/media and missing branch-name presentation above. The hero uses a restrained automatic three-photo crossfade, without a selection picker, video or “سالن ممتاز پونک” subtitle. Hover/offscreen/hidden-tab pause and a static reduced-motion first frame are implemented. The closer work film belongs behind “هنر ما در جزئیات است”; the owner explicitly requested removing its visible pause button. Reduced-motion/save-data retains the poster and offscreen/tab pause remains. The About film and full gallery videos retain their controls. Replace the decorative line-art comb/scissors with the generated photographic cutout in data/barber-tools-provenance.json. Remove repeated diagonal arrows and the three comparison preset buttons; retain the actual touch/keyboard Before/After slider. The portfolio title is “گالری تصاویر”.

The owner confirmed the second branch name فرشته and requested removing synthetic business data from the active owner dataset. Only پونک and فرشته are seeded for new owner installations; no Fereshteh address, working hours, service assignment or commercial policy is inferred. Preserve supplied menu/contact/staff facts. Regression fixtures remain confined to disposable test databases, never the active owner database.

The owner separately authorized a server-hosted employer review on a separate port, while preserving the other site. This permits an access-controlled private review instance, not public media publication or production activation. No private assets enter GitHub or the public source ZIP. Existing production/authentication guards remain unchanged.
