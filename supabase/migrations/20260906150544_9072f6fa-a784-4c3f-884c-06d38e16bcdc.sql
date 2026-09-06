create extension if not exists "pgcrypto";
create extension if not exists "postgis";

do $$ begin
  create type account_type as enum ('client','vendor','both','admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type vendor_status as enum ('draft','pending_review','active','suspended','rejected','closed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type verification_status as enum ('not_started','submitted','under_review','additional_info_required','approved','rejected','suspended');
exception when duplicate_object then null; end $$;

do $$ begin
  create type business_type as enum ('individual','sole_proprietorship','partnership','limited_company','nonprofit','other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type pricing_type as enum ('fixed','starting_from','hourly','daily','per_person','per_unit','custom_quote');
exception when duplicate_object then null; end $$;

do $$ begin
  create type listing_type as enum ('service','rental','product');
exception when duplicate_object then null; end $$;

do $$ begin
  create type availability_status as enum ('available','tentative','booked','unavailable');
exception when duplicate_object then null; end $$;

do $$ begin
  create type request_status as enum ('draft','submitted','viewed','responded','accepted','declined','expired','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type quote_status as enum ('draft','sent','viewed','revision_requested','accepted','rejected','expired');
exception when duplicate_object then null; end $$;

do $$ begin
  create type booking_status as enum ('confirmed','in_progress','completed','cancelled','disputed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type payment_status as enum ('pending','processing','paid','failed','refunded','partially_refunded','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type payment_type as enum ('deposit','milestone','balance','full_payment','refund');
exception when duplicate_object then null; end $$;

do $$ begin
  create type message_type as enum ('text','image','document','system','quote','booking','payment');
exception when duplicate_object then null; end $$;

do $$ begin
  create type media_type as enum ('image','video','document');
exception when duplicate_object then null; end $$;

do $$ begin
  create type event_status as enum ('draft','planning','confirmed','in_progress','completed','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type event_visibility as enum ('private','team');
exception when duplicate_object then null; end $$;

do $$ begin
  create type priority_level as enum ('low','medium','high','critical');
exception when duplicate_object then null; end $$;

do $$ begin
  create type dispute_status as enum ('open','under_review','resolved','closed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type kyc_document_status as enum ('pending','approved','rejected');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  last_name text,
  display_name text,
  avatar_url text,
  phone text,
  email text,
  account_type account_type not null default 'client',
  country_code text default 'NG',
  city text,
  timezone text default 'Africa/Lagos',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  country text not null,
  state text,
  city text not null,
  district text,
  address text,
  latitude double precision,
  longitude double precision,
  postal_code text,
  coordinates geography(point,4326),
  created_at timestamptz not null default now()
);

create index if not exists locations_coordinates_gix
  on public.locations using gist(coordinates);

create table if not exists public.vendors (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  business_name text not null,
  slug text not null unique,
  description text,
  business_type business_type not null default 'individual',
  logo_url text,
  cover_image_url text,
  website text,
  email text,
  phone text,
  whatsapp_number text,
  founded_year integer,
  status vendor_status not null default 'draft',
  verification_status verification_status not null default 'not_started',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists vendors_owner_idx on public.vendors(owner_id);
create index if not exists vendors_status_idx on public.vendors(status);
create index if not exists vendors_verification_idx on public.vendors(verification_status);

create table if not exists public.vendor_members (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  status text not null default 'active',
  invited_at timestamptz,
  joined_at timestamptz default now(),
  unique(vendor_id,user_id)
);

create table if not exists public.vendor_locations (
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  location_id uuid not null references public.locations(id) on delete cascade,
  is_primary boolean not null default false,
  service_radius_km numeric(8,2) default 25,
  primary key(vendor_id,location_id)
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.categories(id) on delete set null,
  name text not null,
  slug text not null unique,
  description text,
  icon text,
  image_url text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists categories_parent_idx on public.categories(parent_id);

create table if not exists public.vendor_categories (
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  primary key(vendor_id,category_id)
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  slug text not null,
  description text,
  pricing_type pricing_type not null default 'custom_quote',
  base_price numeric(14,2),
  minimum_price numeric(14,2),
  maximum_price numeric(14,2),
  currency char(3) not null default 'NGN',
  duration_value numeric(10,2),
  duration_unit text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(vendor_id,slug)
);

create index if not exists services_vendor_idx on public.services(vendor_id);
create index if not exists services_category_idx on public.services(category_id);

create table if not exists public.rental_items (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  slug text not null,
  description text,
  price numeric(14,2) not null,
  currency char(3) not null default 'NGN',
  pricing_unit text not null default 'day',
  quantity_available integer not null default 1 check(quantity_available >= 0),
  security_deposit numeric(14,2),
  replacement_value numeric(14,2),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(vendor_id,slug)
);

create index if not exists rental_vendor_idx on public.rental_items(vendor_id);
create index if not exists rental_category_idx on public.rental_items(category_id);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  slug text not null,
  description text,
  price numeric(14,2) not null,
  currency char(3) not null default 'NGN',
  quantity_available integer check(quantity_available is null or quantity_available >= 0),
  sku text,
  product_type text not null default 'physical',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(vendor_id,slug)
);

create table if not exists public.portfolio_projects (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  title text not null,
  description text,
  event_type text,
  client_name text,
  event_date date,
  location text,
  featured boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.portfolio_media (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.portfolio_projects(id) on delete cascade,
  media_type media_type not null,
  media_url text not null,
  thumbnail_url text,
  caption text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.vendor_equipment (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  brand text,
  model text,
  description text,
  quantity integer not null default 1 check(quantity >= 0),
  ownership_type text default 'owned',
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.vendor_availability (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status availability_status not null,
  note text,
  check(ends_at > starts_at)
);

create index if not exists vendor_availability_range_idx
  on public.vendor_availability(vendor_id,starts_at,ends_at);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references public.profiles(id) on delete restrict,
  title text not null,
  slug text,
  event_type text,
  description text,
  event_date date,
  start_time time,
  end_time time,
  timezone text not null default 'Africa/Lagos',
  guest_count integer,
  budget_min numeric(14,2),
  budget_max numeric(14,2),
  currency char(3) not null default 'NGN',
  venue_name text,
  location_id uuid references public.locations(id) on delete set null,
  status event_status not null default 'draft',
  visibility event_visibility not null default 'private',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists events_organizer_idx on public.events(organizer_id);
create index if not exists events_date_idx on public.events(event_date);

create table if not exists public.event_members (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  permissions jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  unique(event_id,user_id)
);

create table if not exists public.event_requirements (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  requirement_type listing_type,
  title text not null,
  description text,
  quantity numeric(12,2) default 1,
  budget_min numeric(14,2),
  budget_max numeric(14,2),
  status text not null default 'open',
  priority priority_level not null default 'medium',
  created_at timestamptz not null default now()
);

create table if not exists public.saved_vendors (
  user_id uuid not null references public.profiles(id) on delete cascade,
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id,vendor_id)
);

create table if not exists public.booking_requests (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete restrict,
  vendor_id uuid not null references public.vendors(id) on delete restrict,
  status request_status not null default 'draft',
  message text,
  requested_start timestamptz,
  requested_end timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists booking_requests_vendor_idx on public.booking_requests(vendor_id,status);
create index if not exists booking_requests_client_idx on public.booking_requests(client_id,status);
create index if not exists booking_requests_event_idx on public.booking_requests(event_id);

create table if not exists public.booking_request_items (
  id uuid primary key default gen_random_uuid(),
  booking_request_id uuid not null references public.booking_requests(id) on delete cascade,
  item_type listing_type not null,
  service_id uuid references public.services(id) on delete set null,
  rental_id uuid references public.rental_items(id) on delete set null,
  product_id uuid references public.products(id) on delete set null,
  description text,
  quantity numeric(12,2) not null default 1,
  requested_price numeric(14,2)
);

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  booking_request_id uuid not null references public.booking_requests(id) on delete cascade,
  vendor_id uuid not null references public.vendors(id) on delete restrict,
  client_id uuid not null references public.profiles(id) on delete restrict,
  quote_number text not null unique,
  status quote_status not null default 'draft',
  subtotal numeric(14,2) not null default 0,
  discount numeric(14,2) not null default 0,
  tax numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  currency char(3) not null default 'NGN',
  valid_until timestamptz,
  notes text,
  terms text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete cascade,
  item_type listing_type,
  service_id uuid references public.services(id) on delete set null,
  rental_id uuid references public.rental_items(id) on delete set null,
  product_id uuid references public.products(id) on delete set null,
  description text not null,
  quantity numeric(12,2) not null default 1,
  unit_price numeric(14,2) not null default 0,
  discount numeric(14,2) not null default 0,
  tax numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete restrict,
  booking_request_id uuid references public.booking_requests(id) on delete set null,
  quote_id uuid references public.quotes(id) on delete set null,
  client_id uuid not null references public.profiles(id) on delete restrict,
  vendor_id uuid not null references public.vendors(id) on delete restrict,
  booking_number text not null unique,
  status booking_status not null default 'confirmed',
  scheduled_start timestamptz,
  scheduled_end timestamptz,
  subtotal numeric(14,2) not null default 0,
  fees numeric(14,2) not null default 0,
  tax numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  currency char(3) not null default 'NGN',
  payment_status payment_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists bookings_vendor_idx on public.bookings(vendor_id,status);
create index if not exists bookings_client_idx on public.bookings(client_id,status);
create index if not exists bookings_event_idx on public.bookings(event_id);

create table if not exists public.booking_items (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  item_type listing_type,
  service_id uuid references public.services(id) on delete set null,
  rental_id uuid references public.rental_items(id) on delete set null,
  product_id uuid references public.products(id) on delete set null,
  description text not null,
  quantity numeric(12,2) not null default 1,
  unit_price numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete restrict,
  payer_id uuid not null references public.profiles(id) on delete restrict,
  payee_vendor_id uuid not null references public.vendors(id) on delete restrict,
  provider text not null,
  provider_reference text,
  amount numeric(14,2) not null,
  currency char(3) not null default 'NGN',
  status payment_status not null default 'pending',
  payment_type payment_type not null,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.vendor_payouts (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete restrict,
  vendor_id uuid not null references public.vendors(id) on delete restrict,
  payment_id uuid references public.payments(id) on delete set null,
  gross_amount numeric(14,2) not null,
  platform_fee numeric(14,2) not null default 0,
  processing_fee numeric(14,2) not null default 0,
  net_amount numeric(14,2) not null,
  status payment_status not null default 'pending',
  scheduled_at timestamptz,
  paid_at timestamptz,
  provider_reference text
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id) on delete cascade,
  booking_request_id uuid references public.booking_requests(id) on delete cascade,
  booking_id uuid references public.bookings(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(conversation_id,user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  message_type message_type not null default 'text',
  body text,
  attachment_url text,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists messages_conversation_idx
  on public.messages(conversation_id,created_at);

create table if not exists public.review_categories (
  id uuid primary key default gen_random_uuid(),
  category_type text,
  name text not null unique,
  description text,
  is_active boolean not null default true
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete restrict,
  reviewer_id uuid not null references public.profiles(id) on delete restrict,
  vendor_id uuid not null references public.vendors(id) on delete restrict,
  overall_rating numeric(2,1) not null check(overall_rating between 1 and 5),
  review_text text,
  status text not null default 'published',
  is_verified boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.review_scores (
  review_id uuid not null references public.reviews(id) on delete cascade,
  review_category_id uuid not null references public.review_categories(id) on delete restrict,
  score numeric(2,1) not null check(score between 1 and 5),
  primary key(review_id,review_category_id)
);

create table if not exists public.vendor_kyc (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null unique references public.vendors(id) on delete cascade,
  verification_type text not null default 'business',
  status verification_status not null default 'not_started',
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  rejection_reason text
);

create table if not exists public.kyc_documents (
  id uuid primary key default gen_random_uuid(),
  kyc_id uuid not null references public.vendor_kyc(id) on delete cascade,
  document_type text not null,
  file_path text not null,
  document_number text,
  status kyc_document_status not null default 'pending',
  uploaded_at timestamptz not null default now()
);

create table if not exists public.verification_actions (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  admin_id uuid not null references public.profiles(id) on delete restrict,
  action text not null,
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists public.disputes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete restrict,
  opened_by uuid not null references public.profiles(id) on delete restrict,
  reason text not null,
  description text,
  status dispute_status not null default 'open',
  resolution text,
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.dispute_messages (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.disputes(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  body text,
  attachment_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  email_enabled boolean not null default true,
  sms_enabled boolean not null default false,
  whatsapp_enabled boolean not null default true,
  push_enabled boolean not null default true
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  reference_type text,
  reference_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  channel text not null,
  notification_type text not null,
  reference_type text,
  reference_id uuid,
  status text not null,
  provider_reference text,
  sent_at timestamptz
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  old_values jsonb,
  new_values jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now()
);

create table if not exists public.platform_settings (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  value jsonb not null,
  description text,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_id uuid references public.events(id) on delete cascade,
  title text,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  role text not null check(role in ('system','user','assistant','tool')),
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_recommendations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  score numeric(5,2),
  reason jsonb,
  model_version text,
  created_at timestamptz not null default now()
);