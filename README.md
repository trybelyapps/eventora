# Eventora Audit Phase

EVENTORA — PHASE 0

Repository & Supabase Technical Audit

You are working on Eventora, a production-grade event vendor marketplace.

You must treat the following documents as the authoritative product architecture:

Eventora Master Build Specification v1.0

Eventora database schema: eventora_schema_v1.sql

Do NOT begin building the marketplace yet.

Do NOT redesign the database.

Do NOT create replacement tables.

Do NOT delete existing tables.

Do NOT make destructive schema changes.

Your responsibility in this phase is to inspect and report the current technical state of the project.

OBJECTIVE

Perform a complete technical audit of the current Eventora project.

Inspect the existing:

repository

frontend architecture

routes

components

Supabase integration

database schema

authentication

Row Level Security

storage

environment configuration

existing Edge Functions

existing API/service layer

TypeScript types

dependencies

Compare the current implementation against the Eventora Master Build Specification.

1. REPOSITORY AUDIT

Report:

framework

framework version

package manager

TypeScript configuration

application entry point

routing architecture

folder structure

component structure

state management

styling system

UI component library

form library

validation library

existing testing setup

linting

formatting

build configuration

Do not modify these systems during the audit.

2. SUPABASE AUDIT

Inspect the Supabase project.

Report whether the following are configured:

Supabase project connection

authentication

email authentication

email verification

password reset

database

storage

Edge Functions

database migrations

Row Level Security

Identify any missing configuration.

3. DATABASE AUDIT

Compare the current database against:

eventora_schema_v1.sql

For every expected table, report:

EXISTS

MISSING

DIFFERENT

UNKNOWN

Expected core entities include:

profiles
locations
vendors
vendor_members
vendor_locations
categories
vendor_categories
services
rental_items
products
portfolio_projects
portfolio_media
vendor_equipment
vendor_availability
events
event_members
event_requirements
saved_vendors
booking_requests
booking_request_items
quotes
quote_items
bookings
booking_items
payments
vendor_payouts
conversations
conversation_members
messages
review_categories
reviews
review_scores
vendor_kyc
kyc_documents
verification_actions
disputes
dispute_messages
notification_preferences
notifications
notification_logs
audit_logs
platform_settings
ai_conversations
ai_messages
ai_recommendations

Do not create or modify any of these tables during this audit.

4. SECURITY AUDIT

Inspect Row Level Security policies.

For each sensitive table identify:

whether RLS is enabled

existing SELECT policies

INSERT policies

UPDATE policies

DELETE policies

Pay particular attention to:

profiles

vendors

vendor_members

booking_requests

quotes

bookings

payments

vendor_payouts

conversations

messages

vendor_kyc

kyc_documents

disputes

audit_logs

Identify possible privilege escalation risks.

Do not automatically fix them yet.

5. STORAGE AUDIT

Check whether these storage buckets exist:

public-assets

vendor-logos

vendor-portfolio

event-assets

private-documents

kyc-documents

chat-attachments

For each bucket report:

exists

public/private

policies

potential security issues

Do not expose KYC documents publicly.

6. AUTHENTICATION AUDIT

Check the current authentication flow.

Verify:

registration

login

logout

email verification

password reset

session persistence

authenticated route protection

user/profile synchronization

Identify anything missing.

7. FRONTEND AUDIT

Identify existing screens and routes.

Map them against the Eventora architecture.

Expected public routes:

/
/discover
/search
/categories
/categories/[slug]
/vendors/[slug]
/how-it-works
/for-vendors
/login
/register

Expected client routes:

/dashboard
/events
/events/new
/events/[id]
/events/[id]/requirements
/saved
/requests
/requests/[id]
/quotes/[id]
/bookings
/bookings/[id]
/messages
/messages/[id]
/notifications
/profile
/settings

Expected vendor routes:

/vendor/dashboard
/vendor/requests
/vendor/requests/[id]
/vendor/bookings
/vendor/bookings/[id]
/vendor/calendar
/vendor/services
/vendor/rentals
/vendor/products
/vendor/portfolio
/vendor/equipment
/vendor/reviews
/vendor/kyc
/vendor/profile
/vendor/analytics

Expected admin routes:

/admin
/admin/users
/admin/vendors
/admin/vendors/[id]
/admin/kyc
/admin/kyc/[id]
/admin/categories
/admin/listings
/admin/requests
/admin/bookings
/admin/reviews
/admin/disputes
/admin/payments
/admin/payouts
/admin/notifications
/admin/audit-logs
/admin/settings

Do not build missing screens yet.

8. COMPONENT AUDIT

Identify whether reusable components already exist for:

buttons

forms

cards

dialogs

tables

navigation

tabs

badges

notifications

file upload

image upload

date selection

location selection

ratings

vendor cards

status badges

loading states

empty states

error states

Report what can be reused.

9. ENVIRONMENT AUDIT

Identify required environment variables.

Do not expose secrets.

Do not print secret values.

Only report variable names and whether they appear configured.

Categorize them:

Public

Safe for browser exposure.

Server-only

Must never reach the browser.

Missing

Required but not configured.

10. DEPENDENCY AUDIT

Identify dependencies already installed.

Categorize them:

UI

database

authentication

forms

validation

maps

payments

messaging

AI

analytics

testing

Identify unnecessary or conflicting dependencies.

Do not remove anything during this audit.

11. ARCHITECTURAL RISKS

Identify any:

duplicate database concepts

insecure client-side logic

exposed secrets

missing RLS

incorrect relationships

duplicated components

unnecessary dependencies

poor folder structure

architectural coupling

performance risks

accessibility problems

Rank each:

CRITICAL
HIGH
MEDIUM
LOW

12. REQUIRED OUTPUT

Return a structured report with these sections:

A. Current Architecture

B. Database Status

C. Authentication Status

D. RLS/Security Status

E. Storage Status

F. Existing Routes

G. Missing Routes

H. Existing Components

I. Environment Configuration

J. Dependencies

K. Critical Risks

L. Recommended Changes

M. Phase 1 Implementation Plan

Do not implement Phase 1 yet.

IMPORTANT

This is an AUDIT ONLY.

Do not:

redesign the database

create replacement tables

delete data

modify production data

change RLS

create payments

create booking logic

create AI functionality

create marketplace functionality

install unnecessary dependencies

Do not make assumptions where information is unavailable.

Clearly identify uncertainty.

The purpose of this phase is to establish an accurate technical baseline before implementation begins.

This project was built with [Lovable](https://lovable.dev).

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/6e7a217d-03cc-405b-869b-4d0f1432c662).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```
