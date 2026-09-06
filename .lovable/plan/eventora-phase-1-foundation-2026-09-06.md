# Eventora — Phase 1: Foundation

The audit is complete. This plan covers **Phase 1 only** — identity, security, storage,
design system, and app shell. No marketplace, booking, payment, messaging, or AI work.

## Points to confirm before I start

1. **Stack.** The specification names Next.js. This project is TanStack Start (React 19 +
   Vite, edge-deployed) and the router cannot be swapped here. It is equivalent in
   capability — server-side rendering, file-based routing, secure server-side logic — but
   your Edge Functions become server functions, and there are no Next.js API routes or
   `next/image`. Everything else in the spec is honoured as written.
2. **App-installability (PWA).** Section 42 asks for a PWA. I propose deferring the
   installable manifest and offline behaviour to a later phase and delivering
   mobile-first responsive layouts now. Say the word if you want it in Phase 1.
3. **Demo data.** Section 57 asks for a lively demo marketplace. Vendors, portfolios and
   bookings depend on Phase 3–6 tables being wired up, so I will seed only categories
   (already in your SQL) in Phase 1 and add the full demo set in Phase 4.

## What Phase 1 delivers

### 1. Backend enabled
Turn on Lovable Cloud (managed Postgres, auth, storage, server-side functions).

### 2. Database — your schema applied unchanged, plus additive safety
`eventora_schema_v1.sql` runs verbatim as the first migration: 44 tables, 19 enums,
triggers, category seeds. No table is renamed, replaced, or dropped.

A second, purely **additive** migration then closes three gaps that would otherwise make
the app unusable or unsafe. No changes to your table structure.

- **Data-API grants.** Your file has none. Without them every query fails with a
  permission error, even for correctly authorised users. Grants are written per table to
  match each table's policies: public-readable tables get anonymous read; user-scoped
  tables get authenticated access only; sensitive tables get server-side access only.
- **Roles moved out of `profiles`.** `profiles.account_type` includes `admin` and users can
  update their own profile — today that means anyone could make themselves an
  administrator. Adds a dedicated roles table plus a secure role-check function (spec
  §35, and your file's own note 1), and narrows the profile-update policy so it cannot
  change account type or verification fields. `account_type` stays in place for the
  client/vendor choice at registration.
- **Missing policies.** RLS is on for all 44 tables but 19 have no policies at all,
  including `payments`, `vendor_payouts`, `vendor_kyc`, `kyc_documents`, `disputes`,
  `audit_logs`, and every line-item table — so nobody, not even the owner or an admin,
  can read them. Adds owner-scoped and admin-scoped policies per §35 and §64: clients see
  their own requests/quotes/bookings/payments, vendors see theirs, KYC is vendor+admin
  only, audit logs are append-only and admin-read.
- **Vendor team access.** Every vendor policy in your file checks the owner only, so
  `vendor_members` grants nothing. Policies are widened to active vendor members, per
  §4.3 and §35.

One dependency check first: your file requires the `postgis` extension. If it is
unavailable I will report back rather than alter the schema.

### 3. Storage
All seven buckets from §37. `public-assets`, `vendor-logos`, `vendor-portfolio` public-read
with owner-scoped writes. `event-assets` and `chat-attachments` private, readable only by
event members / conversation members. `private-documents` and `kyc-documents` private with
no public path at all — vendor owner and administrators only.

### 4. Authentication (§8, §9)
Register (first name, last name, email, phone, password, account type), login, logout, email
verification, forgot/reset password, session persistence. `handle_new_user()` in your schema
already creates the profile row. Notification preferences are created on first sign-in.

Route protection: a signed-in area gate, plus role gates for the vendor and admin sections
enforced server-side through the role-check function — never in the browser (§64, §70).
Header reflects session state with a working sign-out.

### 5. Design system (§38)
Montserrat display, Inter interface, loaded properly for the edge runtime. Eventora Blue
primary, Electric Purple secondary, Warm Gold accent used sparingly, near-black/slate/white
neutrals — all as semantic tokens, so no screen hardcodes a colour. Rounded cards, subtle
shadows, generous whitespace, premium dark sections, smooth transitions, reduced-motion
support.

### 6. Foundational components (§39, §49, §56)
Built on the existing shadcn primitives, adding what does not exist: `SearchInput`,
`LocationPicker`, `CurrencyInput`, `Rating`, `VendorBadge`, `StatusBadge`, `PriceDisplay`,
`FileUploader`, `ImageUploader`, `EmptyState`, `LoadingState`, `ErrorState`, `NotificationItem`.
`VendorCard`, `QuoteTable`, `BookingSummary`, `MessageComposer`, `Map` and `Timeline` follow
in the phases that use them. Keyboard navigation, visible focus, labels, contrast and alt
text are built in, not retrofitted.

### 7. App shell (§42)
Public header/footer, client and vendor authenticated shells with role-aware navigation,
mobile bottom navigation (client: Home, Discover, Events, Messages, Profile / vendor:
Dashboard, Requests, Calendar, Messages, More), and an admin shell. Loading, empty and
error states wired at every level.

### 8. Route skeletons
All 61 routes from §6 created with correct paths, guards, page metadata, and honest "coming
in Phase N" placeholders — so navigation and links work end to end and nothing 404s. Real
screens land in their own phases.

### 9. Service layer (§58)
`AuthService` and a typed data-access foundation implemented as secure server-side
functions, with the module boundaries for the remaining twelve services stubbed so later
phases drop into place instead of scattering database calls across screens.

## Explicitly out of scope for Phase 1
Marketplace and search, vendor onboarding screens, events, booking requests, quotes,
bookings, payments, payouts, messaging, WhatsApp, reviews, disputes, admin screens beyond
the shell, AI. Payment and messaging providers are not chosen or installed in this phase.

## Technical notes
- Migration order: your SQL verbatim, then the additive grants/roles/policies migration.
- Server-side only: booking, quote acceptance, payments, payouts, KYC approval, suspension,
  dispute resolution, notification dispatch, review eligibility, and admin operations —
  scaffolded as server functions in this phase, implemented in their own phases (§36).
- Service-role credentials never reach the browser; secrets are read only inside server
  handlers.
- Nothing destructive: no drops, no renames, no data deletion, no changes to your schema's
  columns, constraints, indexes, or relationships.
