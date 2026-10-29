# Visual and Functional Acceptance Criteria

## PR / screen review procedure
1. Screenshot all relevant pages at `1440x900`, `390x844` and where needed `1024x768` with Playwright. Save to `artifacts/screenshots/` in Codex project.
2. Put rendered screenshots side-by-side with the appropriate `screen-references/` crop. **Human visual review is mandatory** because AI collages contain inaccessible/unrealistic components, and direct pixel similarity can be misleading.
3. Inspect main regions in this order: overall composition -> image selection/crop -> text placement -> RTL alignment -> colors -> typography -> spacing -> borders -> interactive details.
4. Independently validate functional behavior: navigation, menu, service filters, gallery before/after interaction, booking form and disabled states, keyboard operations, focus styles, screen readers and loading/error states.
5. Add a short implementation note that lists intentional differences from the reference, and a screenshot before any reviewer approves a page.
6. No approval = no next screen. No backend/payment claims from static mockups.

## Must-pass visual constraints
- Above-the-fold hero follows concept: split dark cinematic imagery and oversized editorial headline, with tasteful gold CTA.
- Six services correspond to brochure labels; no random service image presented as a specific procedure.
- Visible image assets MUST come from approved client images or separately approved assets.
- No arbitrary UI redesign of the approved dark/gold/ivory language.
- Full RTL and responsive; no horizontal overflow; tap targets 44px preferred; sufficient contrast.
- All booking amounts and cancellation terms come from backend policies; no hardcoded fictional prices.
- Branch 2 remains unconfirmed until real metadata is supplied; do not invent its name, address, photos or schedule.
- Empty/loading/error states are designed intentionally.

## End-to-end MVP behavior (future phases)
- Admin can create/activate/deactivate branches, assign barbers, set branch-service-specific price and duration.
- Prevent double-booking with server-side transactional control; a calendar highlight is not a reservation guarantee.
- Pricing/deposit/refund policies are configurable and versioned; booking stores a snapshot of accepted rules.
- Gallery uploads are authenticated, validated, converted to appropriate sizes, and optionally moderated; no publication without consent.
- Notifications run asynchronously; Telegram/Bale only when user initiated/authorized channel linking, with SMS fallback based on preferences.
