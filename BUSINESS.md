# Hotel8:ePMS - Business Requirements & Functionality

> Audience: product owners, business analysts, and anyone evaluating what
> Hotel8:ePMS **does for the business**. For architecture read `README.md`;
> for wire-level detail read `DESIGN.md`.

## 1. Business Purpose

- Give hotel staff the property-management console: reservations, front
  desk, housekeeping, cashiering, rate management, blocks and events - the
  operational heart of the hotel.
- Shorten guest-facing operations: check-in/out in a few clicks with live
  room status and folio visibility.
- Keep daily financial control: folio charges/payments with full audit and
  End-of-Day close with exception tracking.
- Serve management with occupancy/revenue dashboards and rate-schedule
  control without leaving the vertical.

## 2. Business Scope (What the Service Provides)

| Capability | Provided by ePMS |
|---|---|
| Front-desk dashboard (occupancy, arrivals, departures, housekeeping, revenue) | ✅ |
| Reservation search, detail, create, edit, cancel, split | ✅ |
| Pre-check-in / check-in / check-out wizard | ✅ |
| Room status grid + housekeeping updates | ✅ |
| Folio view + charge/payment posting | ✅ |
| Rate plans + schedules view | ✅ |
| Blocks + events view | ✅ |
| Guest profiles (CRM) lookup | ✅ |
| EOD dashboard + exceptions | ✅ |
| Property audit-log view | ✅ |
| Availability + inventory views | ✅ |
| RFW operations pages (service-defined admin UI hosted in-app) | ✅ |
| Full rate-plan CRUD, block/event CRUD admin | ✅ via the service RFW admin pages (Dash + in-app RFW host on the RFW Ops tab) |
| Distribution channel management | ❌ delegated - Hotel8:Distrib (Dash) |
| POS terminal | ❌ delegated - Hotel8:ePOS |
| Guest-facing apps | ❌ delegated - eBooking / eGuest / eKiosk |
| Payment acceptance | ❌ delegated - PMS → Bill8 server-side |

## 3. Business Capabilities

### Front desk

| Capability | Business rule |
|---|---|
| Arrivals/departures | The dashboard lists today's arrivals and departures with status, so the desk sees the day at a glance. |
| Check-in | Check-in requires a room assignment; pre-check-in data (registration card) already captured by eGuest reduces the wizard to allocate-and-confirm. |
| Check-out | Check-out settles against the folio - the console surfaces outstanding balances before the room is released. |
| Room status | Room statuses (clean/dirty/inspected/OOS) are updated from the grid; housekeeping and front office stay in sync on one view. |

### Cashiering

| Capability | Business rule |
|---|---|
| Folio management | Charges and payments post against the reservation's folio; the console never edits money rows directly - each posting is a server action. |
| Audit | Every staff mutation is journaled by PMS with the acting staff identity; the audit-log view provides read-back. |

### Revenue & inventory

| Capability | Business rule |
|---|---|
| Rate plans & schedules | Revenue managers see rate plans and their schedules; changes ride the PMS rate engine (schedules fetched per plan). |
| Availability & inventory | Availability and inventory views give the allocation picture for the property. |

### Group & catering

| Capability | Business rule |
|---|---|
| Blocks & events | Group blocks and function-space events are visible with their state; detailed sales workflows ride the service's admin pages. |

### Property control

| Capability | Business rule |
|---|---|
| EOD | The night auditor runs End-of-Day from the console; exceptions surface in the dashboard before and after close. |
| RFW ops pages | The operations destination renders the PMS service's own admin UI definitions in-app, so service-side admin pages and staff workflows share one surface. |

## 4. Business Events (Outbound)

ePMS emits no events; staff actions generate events in Hotel8:PMS:

| Business moment | Event family (owner) |
|---|---|
| Reservation created/edited/cancelled/split | PMS reservation events |
| Check-in / check-out / pre-check-in | PMS front-office events |
| Charge/payment posted | PMS cashiering events |
| Room status change | PMS housekeeping events |
| EOD executed | PMS end-of-day events |

**Inbound:** none (the console is read+write over HTTP only).

## 5. Business Rules & Invariants

1. The console operates strictly through the BFF with the staff session; no
   direct PMS/database access from the app.
2. The property under management is the runtime context's environment - the
   console cannot act across environments.
3. Money postings are server actions; the console never computes or edits
   folio figures directly.
4. Check-in/out are state machines - a reservation cannot be checked in
   twice, or out with an unsettled folio (server-enforced).
5. Every mutation is audit-attributed to the acting staff member.
6. RFW-rendered pages use the same authorization surface as native screens -
   no separate admin backdoor.
7. Widget hosts render what the server declares; the console adds no business
   logic of its own.

## 6. Target-User Roles & Use Cases

| Persona | What they do with ePMS |
|---|---|
| Front-desk agent | Runs arrivals/check-ins/check-outs, assigns rooms, handles walk-ins via reservations. |
| Housekeeping supervisor | Updates room status grid, tracks task progress against the floor. |
| Cashier/night auditor | Posts charges/payments, reconciles folios, runs EOD. |
| Revenue manager | Inspects rate plans and schedules, availability, inventory. |
| Sales & catering | Reviews blocks and event bookings. |
| General manager | Monitors dashboard KPIs and the audit log. |

## 7. KPIs / Success Criteria

- **Check-in/out time** per guest (desk productivity).
- **Folio accuracy** - postings match Bill8/folio settlements with zero
  manual correction.
- **EOD completion** within the nightly window; exceptions resolved before
  close.
- **Dashboard trust** - occupancy/revenue figures reconcile against PMS
  reports.
- **Security posture** - zero cross-env actions; zero unaudited mutations;
  token-free client.

## 8. Dependencies & Reliance on Other Services

| Reliance | For |
|---|---|
| Hotel8:PMS | All staff domain operations + RFW admin UI |
| Sentin8:BFF | Transport, staff session, tenant resolution |
| Sentin8:Auth (staff env) | Staff identity + role scopes (via BFF) |
| Sentin8:App | Runtime context, listing, DCR bootstrap |
| Sentin8:Proxy | TLS host-resolution headers at bootstrap |
| Bill8 (server-side) | Folio settlement (not called by the app) |

## 9. Acceptance Criteria

1. A staff member signs in and sees the property dashboard with live
   occupancy/arrivals/departures.
2. A reservation can be searched, opened, edited, and cancelled; a split
   produces two reservations with correct folio inheritance.
3. Check-in assigns a room and flips the reservation state; the room grid
   reflects occupancy immediately.
4. Folio charges/payments post and appear with running balance.
5. EOD runs and exceptions list before/after close; the audit log shows the
   acting staff member for each mutation.
6. The RFW operations destination renders service-defined pages with working
   data/submit endpoints.
7. No app call exists outside `/proxy/hotel8-pms/*`.

## 10. Open Business Questions

- Multi-property environments: property selection when an env hosts more than
  one property (property registry read).
- Role boundaries: which screens/actions gate by which staff roles, and where
  manager approvals are needed server-side.
- Offline tolerance for check-in/out (designed against; awaiting the platform
  offline pattern).

---

**Design attribution:** hotel8:epms and its underlying concepts were designed by Hamid Jahanzad <Hamid@Jahanzad.com>.
