# Eventora — Phase 0 Reconciliation

Status: reconciliation only. No application code, schema, policy, storage or integration
change has been made in producing this document. Phase 1 implementation has not started.

Infrastructure of record: connected GitHub repository (code) and connected Supabase
project (database, auth, RLS, storage, realtime, functions, migrations). Both remain
authoritative. No second backend, no second database, no provider switch.

Verified live against the connected Supabase project on 2026-09-07.

---

## A. Database reconciliation

Measured state of the `public` schema:

| Measure | Value |
| --- | --- |
| Tables in `public` | 46 |
| — Eventora application tables | 45 |
| — created by the PostGIS extension (`spatial_ref_sys`) | 1 |
| Enum types | 19 |
| Tables with row-level security enabled | 0 |
| Policies | 0 |
| Data-API grants to `anon` / `authenticated` / `service_role` | 0 |
| `has_role()` function | absent |
| Storage buckets | 0 |
| Rows in `categories` / `review_categories` (seeds) | 0 |
| Auth users | 0 |

### The 44 vs 45 discrepancy

The earlier audit reported 44 tables. The authoritative count in the live database is
**45 Eventora tables**, plus `spatial_ref_sys` which belongs to the PostGIS extension and
is not ours. Nothing extra was invented and nothing was dropped: the 45 are exactly the
`CREATE TABLE` statements in `eventora_schema_v1.sql`. The earlier "44" was a counting
error in my own summary, not a schema difference. The definitive inventory, grouped:

- **Identity (3):** `profiles`, `notification_preferences`, `audit_logs`
- **Vendor (11):** `vendors`, `vendor_members`, `vendor_categories`, `vendor_locations`,
  `vendor_availability`, `vendor_equipment`, `vendor_kyc`, `kyc_documents`,
  `verification_actions`, `portfolio_projects`, `portfolio_media`
- **Catalogue (5):** `categories`, `services`, `rental_items`, `products`, `saved_vendors`
- **Events (3):** `events`, `event_members`, `event_requirements`
- **Requests & quotes (4):** `booking_requests`, `booking_request_items`, `quotes`,
  `quote_items`
- **Bookings (2):** `bookings`, `booking_items`
- **Money (3):** `payments`, `vendor_payouts`, `platform_settings`
- **Messaging (3):** `conversations`, `conversation_members`, `messages`
- **Reviews (3):** `reviews`, `review_categories`, `review_scores`
- **Disputes (2):** `disputes`, `dispute_messages`
- **Notifications (2):** `notifications`, `notification_logs`
- **AI (3):** `ai_conversations`, `ai_messages`, `ai_recommendations`
- **Geography (1):** `locations`

Please confirm this 45-table list matches your approved document. If your document counts
44, the difference is a counting convention (most likely `notification_preferences`, a 1:1
child of `profiles` rather than an entity), not a structural divergence — no table will be
added, renamed, merged or removed to reconcile a count.

### Two gaps that must close before any screen can work

1. **No grants.** `eventora_schema_v1.sql` contains no `GRANT` statements. Supabase's
   Data API does not grant `public`-schema privileges by default, so every query currently
   fails with a permission error even for a correctly authorised user. The database is
   presently unreachable from the application — which also means nothing is exposed today.
2. **RLS is off and there are no policies.** The tables were created without
   `ENABLE ROW LEVEL SECURITY` taking effect. This is safe only because there are no
   grants; the moment grants are added without policies, everything is world-readable.
   Grants and policies must therefore land in the **same** migration, never separately.

Both are additive. No table structure, column, constraint, index or relationship changes.

---

## B. Page reconciliation

The 61 figure is 53 primary screens plus 8 non-screen routes. Nothing was added beyond
your specification; the 8 are technical routes a working app needs.

| Area | Primary screens | Utility routes |
| --- | --- | --- |
| Public | 10 | 1 (`/auth/callback`) |
| Client | 16 | 1 (`/`, the landing/index route) |
| Vendor | 14 | 1 (vendor onboarding shell/step router) |
| Admin | 13 | 1 (admin shell/index redirect) |
| Cross-cutting | — | 4 (`/auth/reset`, `/auth/verify`, 404, error boundary) |
| **Total** | **53** | **8** |

If you would rather see exactly 53 route files, the utility routes can be folded into
their parents (callback handled inside `/auth`, resets as query modes, shells as layout
files with no path of their own). My recommendation is to keep them separate: OAuth
callbacks and password-reset links must be distinct URLs to work with the email and
provider redirect flows. Tell me which you want and I will build to that number.

Every route in Phase 1 is a guarded skeleton with correct metadata and an honest
"coming in Phase N" placeholder. No marketplace functionality is implemented.

---

## C. Admin authorization architecture

Admin privilege will never be derived from a client-editable field.

- `profiles.account_type` keeps its `client` / `vendor` / `both` values for the
  registration choice only. **It stops being an authorization input.** The `admin` value in
  that enum is never honoured by any policy or server function.
- A dedicated table `public.user_roles (user_id, role app_role)` with a unique
  `(user_id, role)` constraint holds privilege. Users can read their own roles and cannot
  write the table at all: no `INSERT`/`UPDATE`/`DELETE` policy exists for `authenticated`.
  Rows are granted only by `service_role`, i.e. by server-side code we control.
- `public.has_role(_user_id uuid, _role app_role)` is `SECURITY DEFINER`, `STABLE`,
  `SET search_path = public`. Every admin policy calls `has_role(auth.uid(), 'admin')`.
  Being a definer function, it avoids recursive RLS evaluation on `user_roles`.
- The profile-update policy is narrowed with a `WITH CHECK` that forbids changing
  `account_type` and any verification field, so a user cannot escalate by editing metadata.
- Route-level admin gates in the browser are convenience only. Authorization is decided by
  the database policy and by server functions; bypassing the UI gains nothing.
- Every privileged action writes to `audit_logs` (append-only, admin-read).

**Change / Reason / Impact / Risk / Rollback:** adds `app_role` enum, `user_roles` table,
`has_role()` function, and tightens one policy on `profiles`. Required because the schema
as approved permits self-service privilege escalation (your rule 6, and the schema file's
own note 1). Affects nothing that currently works — there are no users and no policies.
Risk: **Low**. Rollback: drop the table, function and enum; restore the original
`profiles` update policy. Non-destructive; no existing data touched.

---

## D. Complete RLS policy plan

Principle: RLS on for all 45 tables; grants matched to policies; `anon` gets read access
only where the product is genuinely public; sensitive tables get no `anon` grant at all.

Three reusable definer helpers keep policies simple and non-recursive:
`has_role(uid, role)`, `is_vendor_member(vendor_id, uid)` (owner **or** active
`vendor_members` row), `is_event_member(event_id, uid)` (organizer **or** active
`event_members` row).

| Table | anon read | Authenticated read | Write | Admin |
| --- | --- | --- | --- | --- |
| `categories`, `review_categories` | yes (active only) | yes | admin only | full |
| `vendors` | yes, `status='active'` only | same + own vendor in any status | vendor members | full |
| `services`, `rental_items`, `products` | yes, active + active vendor | same | vendor members | full |
| `portfolio_projects`, `portfolio_media` | yes, active vendor | same | vendor members | full |
| `vendor_categories`, `vendor_locations`, `vendor_equipment` | yes (public rows) | same | vendor members | full |
| `vendor_availability` | no | vendor members | vendor members | full |
| `vendor_members` | no | own vendor's members | vendor owner/admin role | full |
| `locations` | yes | yes | server-side only | full |
| `reviews`, `review_scores` | yes, `status='published'` | same + own | reviewer, once booking completed | full |
| `profiles` | no | own row; public display fields of vendor owners | own row, minus `account_type` and verification fields | full |
| `user_roles` | no | own roles | none (server only) | full |
| `notification_preferences`, `notifications`, `notification_logs` | no | own | own (`notifications` read-flag only) | read |
| `saved_vendors` | no | own | own | read |
| `events` | no | organizer + event members | organizer, members by permission | full |
| `event_members`, `event_requirements` | no | event members | organizer | full |
| `booking_requests`, `booking_request_items` | no | client, target vendor's members | client creates; vendor updates status | full |
| `quotes`, `quote_items` | no | issuing vendor's members, addressed client | vendor drafts/sends; client accept/reject via server fn | full |
| `bookings`, `booking_items` | no | client, vendor members | server functions only | full |
| `payments` | no | payer, payee vendor members | **none** — server/webhook only | read |
| `vendor_payouts` | no | vendor members | **none** — server only | full |
| `vendor_kyc`, `kyc_documents` | no | vendor members | vendor uploads; status by admin only | full |
| `verification_actions` | no | none | none | full |
| `conversations`, `conversation_members` | no | conversation members | server fn on request/booking creation | read |
| `messages` | no | conversation members | member insert, own read-receipt update | read |
| `disputes`, `dispute_messages` | no | booking parties + opener | parties insert; resolution admin only | full |
| `audit_logs` | no | none | insert by server only, never update/delete | read |
| `platform_settings` | no | none | admin only | full |
| `ai_conversations`, `ai_messages` | no | own | own | read |
| `ai_recommendations` | no | event members | server only | read |
| `spatial_ref_sys` | extension-owned; no grants, not exposed |

Enforcement notes: money, status transitions and privilege changes have **no**
client-writable path — they are server functions running with verified identity, so a
direct API call from a hostile client cannot create a booking, mark a payment paid, issue a
payout, approve KYC, publish a review without a completed booking, or resolve a dispute.

---

## E. Storage security matrix

Seven areas, exactly as approved. Paths are prefix-scoped so a policy can prove ownership
from the object key.

| Area | Public | Path convention | Read | Write | Delete |
| --- | --- | --- | --- | --- | --- |
| `public-assets` | yes | `<folder>/<file>` | anyone | admin only | admin |
| `vendor-logos` | yes | `<vendor_id>/…` | anyone | vendor members | vendor members |
| `vendor-portfolio` | yes | `<vendor_id>/<project_id>/…` | anyone | vendor members | vendor members |
| `event-assets` | no | `<event_id>/…` | event members | event members | organizer |
| `chat-attachments` | no | `<conversation_id>/…` | conversation members | conversation members | sender |
| `private-documents` | no | `<owner_id>/…` | owner + admin | owner | owner + admin |
| `kyc-documents` | no | `<vendor_id>/…` | vendor owner + admin only | vendor owner | admin only |

`kyc-documents` and `private-documents` are private with no public URL path whatsoever;
access is only via short-lived signed URLs minted by a server function after the caller's
right to the object is checked. Buckets are created with the storage tooling; policies on
`storage.objects` are written as migrations, so they live in GitHub like everything else.
File-type and size limits are set per bucket (images for logos/portfolio, PDF+image for
KYC and documents).

---

## F. Authentication architecture

- **Signup:** email + password with first name, last name, phone and account type. Email
  confirmation on; no anonymous sign-up. Google sign-in offered alongside, configured in
  the same change so the first attempt cannot fail.
- **Profile creation:** the `handle_new_user()` trigger from your schema creates the
  `profiles` row from signup metadata. No client-side profile insert exists, so a profile
  cannot be created with forged fields. `notification_preferences` is created in the same
  trigger path.
- **Sessions:** persisted and auto-refreshed in the browser; server functions never trust a
  client-supplied identity — they verify the bearer token and derive `user_id` from the
  verified claims. Protected server functions require that middleware; an unauthenticated
  call is rejected before any query runs.
- **Password reset & verification:** forgot-password email with a dedicated reset URL,
  email-verification landing route, and a resend path. Reset does not log the user in
  implicitly beyond the recovery session.
- **Role handling:** account type from `profiles` selects the client or vendor experience.
  Admin comes only from `user_roles` via `has_role()`. Route gates redirect
  unauthenticated users; the database decides what they can actually touch.
- **Sign-out** clears the session everywhere; header reflects real session state.

---

## G. Financial security architecture

Not implemented in Phase 1; the architecture is fixed now so later phases cannot weaken it.

- Clients never write `payments`, `vendor_payouts` or booking totals. There is no
  client-writable path to any monetary column — policies grant no insert/update.
- Amounts are always recomputed server-side from the accepted quote's line items. A
  client-submitted total is discarded, never trusted.
- Provider webhooks arrive on a dedicated public endpoint that verifies the provider's
  signature with a server-only secret before reading the body, and is idempotent on the
  provider reference so a replayed event cannot double-credit.
- Commission, platform fee and processing fee are computed server-side from
  `platform_settings`; payout `net_amount` is derived, never supplied.
- Payout release is a server-side state machine gated on booking completion and dispute
  status; an open dispute blocks release.
- Refunds and partial refunds go through the provider API server-side and are recorded as
  `payments` rows of type `refund`; balances are never edited in place.
- Every monetary state change writes an `audit_logs` entry with actor, before and after.
- Secret keys (provider secret key, webhook secret, service-role key, AI and messaging
  secrets) live only in server-side configuration, are read inside handlers, are never
  bundled into client code, and are never committed to GitHub.

---

## H. Outstanding risks and decisions needed

| # | Item | Type | Needs from you |
| --- | --- | --- | --- |
| 1 | **Framework.** Your specification names Next.js; this project is TanStack Start (React 19 + Vite, SSR, file routing, server functions). Equivalent in capability and fully portable — standard React, standard Vite, deployable from GitHub to any host. The router cannot be swapped inside Lovable. | Architectural | Confirm you accept TanStack Start, or plan a post-export port. |
| 2 | **Payments provider** — Stripe vs Paddle vs a local/African processor (Paystack, Flutterwave). Determines webhook shape, payout mechanics and KYC. | Product | Decide before Phase 6. |
| 3 | **Commission model** — platform fee %, processing fee handling, who bears it. Not in the documents I have. | Product | Provide the formula. |
| 4 | **Deposit / milestone / balance split** and cancellation & refund rules. Unspecified. | Product | Provide the rules. |
| 5 | **Currency** — single currency or multi-currency with FX. Schema carries a `currency` column per row, which allows multi. | Product | Decide. |
| 6 | **WhatsApp provider** (Meta Cloud API vs Twilio vs 360dialog) and template approval ownership. | Product | Decide before notifications phase. |
| 7 | **Specification completeness.** The uploaded `Eventora.pdf` is a 2-page summary, not the full Master Build Specification — no screen-level requirements, notification triggers or fee formulas. I am building to the summary plus your rules. | Process | Upload the full specification. |
| 8 | **44 vs 45 table count** — see section A. | Verification | Confirm the inventory. |
| 9 | **53 vs 61 routes** — see section B. | Decision | Keep 8 utility routes separate, or fold them in. |
| 10 | **No automated tests** in the repository. Financial and RLS logic warrants them. | Quality | Approve adding a test setup in a later phase. |
| 11 | **PWA / installability** deferred out of Phase 1 in favour of mobile-first responsive layouts. | Product | Confirm the deferral. |
| 12 | **Realtime scope** — messaging and notifications are the natural candidates. | Product | Confirm where realtime is wanted. |

---

## Portability statement

Everything produced for Eventora is ordinary React, TypeScript, Vite and SQL in the
connected GitHub repository, talking to your Supabase project through the standard
`@supabase/supabase-js` client and standard environment variables. All schema, policy and
storage-policy changes are checked-in migration files. Clone, `bun install` (or npm),
set the environment variables, build, deploy anywhere — no Lovable runtime, no proprietary
service in the request path, no hidden logic outside the repository.
