// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

/// PMS data models.
///
/// Simple Dart classes mirroring the PMS PMS contract shapes (see
/// `epms/DESIGN.md` §3) and the BFF
/// proxy surface for PMS. PMS is the hotel property management system
/// staff app - reservations, front desk, cashiering, housekeeping, rates,
/// blocks, profiles, back office, and reports.

import 'dart:convert';

// ═══════════════════════════════════════════════════════════════════════════
// Dashboard
// ═══════════════════════════════════════════════════════════════════════════

/// Summary of today's front-desk dashboard metrics.
class Dashboard {
  final DateTime businessDate;
  final int arrivalsExpected;
  final int arrivalsCheckedIn;
  final int departuresExpected;
  final int departuresCheckedOut;
  final int inHouseGuests;
  final int totalRooms;
  final int availableRooms;
  final int occupancyPercent;
  final double roomRevenue;
  final double foodRevenue;
  final double beverageRevenue;
  final double otherRevenue;
  final double totalRevenue;
  final double adr;
  final double revpar;
  final HousekeepingSummary housekeeping;

  const Dashboard({
    required this.businessDate,
    required this.arrivalsExpected,
    required this.arrivalsCheckedIn,
    required this.departuresExpected,
    required this.departuresCheckedOut,
    required this.inHouseGuests,
    required this.totalRooms,
    required this.availableRooms,
    required this.occupancyPercent,
    required this.roomRevenue,
    required this.foodRevenue,
    required this.beverageRevenue,
    required this.otherRevenue,
    required this.totalRevenue,
    required this.adr,
    required this.revpar,
    required this.housekeeping,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
        businessDate: DateTime.tryParse(json['business_date'] as String? ?? '') ??
            DateTime.now(),
        arrivalsExpected: json['arrivals_expected'] as int? ?? 0,
        arrivalsCheckedIn: json['arrivals_checked_in'] as int? ?? 0,
        departuresExpected: json['departures_expected'] as int? ?? 0,
        departuresCheckedOut: json['departures_checked_out'] as int? ?? 0,
        inHouseGuests: json['in_house_guests'] as int? ?? 0,
        totalRooms: json['total_rooms'] as int? ?? 0,
        availableRooms: json['available_rooms'] as int? ?? 0,
        occupancyPercent: (json['occupancy_percent'] as num?)?.toInt() ?? 0,
        roomRevenue: (json['room_revenue'] as num?)?.toDouble() ?? 0,
        foodRevenue: (json['food_revenue'] as num?)?.toDouble() ?? 0,
        beverageRevenue: (json['beverage_revenue'] as num?)?.toDouble() ?? 0,
        otherRevenue: (json['other_revenue'] as num?)?.toDouble() ?? 0,
        totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
        adr: (json['adr'] as num?)?.toDouble() ?? 0,
        revpar: (json['revpar'] as num?)?.toDouble() ?? 0,
        housekeeping: HousekeepingSummary.fromJson(
            json['housekeeping'] as Map<String, dynamic>? ?? const {}),
      );
}

class HousekeepingSummary {
  final int clean;
  final int dirty;
  final int inspected;
  final int turndown;
  final int outOfOrder;

  const HousekeepingSummary({
    this.clean = 0,
    this.dirty = 0,
    this.inspected = 0,
    this.turndown = 0,
    this.outOfOrder = 0,
  });

  factory HousekeepingSummary.fromJson(Map<String, dynamic> json) =>
      HousekeepingSummary(
        clean: json['clean'] as int? ?? 0,
        dirty: json['dirty'] as int? ?? 0,
        inspected: json['inspected'] as int? ?? 0,
        turndown: json['turndown'] as int? ?? 0,
        outOfOrder: json['out_of_order'] as int? ?? 0,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Arrival / Departure
// ═══════════════════════════════════════════════════════════════════════════

class Arrival {
  final String reservationId;
  final String confirmationNumber;
  final String guestName;
  final String? roomType;
  final String? roomNumber;
  final DateTime arrivalDate;
  final DateTime departureDate;
  final int nights;
  final double? rate;
  final String status;
  final String? vipCode;
  final bool preRegistered;
  final bool? packageIncluded;

  const Arrival({
    required this.reservationId,
    required this.confirmationNumber,
    required this.guestName,
    this.roomType,
    this.roomNumber,
    required this.arrivalDate,
    required this.departureDate,
    required this.nights,
    this.rate,
    required this.status,
    this.vipCode,
    this.preRegistered = false,
    this.packageIncluded,
  });

  factory Arrival.fromJson(Map<String, dynamic> json) => Arrival(
        reservationId: json['reservation_id'] as String,
        confirmationNumber: json['confirmation_number'] as String,
        guestName: json['guest_name'] as String,
        roomType: json['room_type'] as String?,
        roomNumber: json['room_number'] as String?,
        arrivalDate: DateTime.parse(json['arrival_date'] as String),
        departureDate: DateTime.parse(json['departure_date'] as String),
        nights: json['nights'] as int? ?? 1,
        rate: (json['rate'] as num?)?.toDouble(),
        status: json['status'] as String? ?? 'reserved',
        vipCode: json['vip_code'] as String?,
        preRegistered: json['pre_registered'] as bool? ?? false,
        packageIncluded: json['package_included'] as bool?,
      );
}

class Departure {
  final String reservationId;
  final String confirmationNumber;
  final String guestName;
  final String? roomNumber;
  final DateTime departureDate;
  final double? balance;
  final String status;
  final bool folioBalanced;

  const Departure({
    required this.reservationId,
    required this.confirmationNumber,
    required this.guestName,
    this.roomNumber,
    required this.departureDate,
    this.balance,
    required this.status,
    this.folioBalanced = false,
  });

  factory Departure.fromJson(Map<String, dynamic> json) => Departure(
        reservationId: json['reservation_id'] as String,
        confirmationNumber: json['confirmation_number'] as String,
        guestName: json['guest_name'] as String,
        roomNumber: json['room_number'] as String?,
        departureDate: DateTime.parse(json['departure_date'] as String),
        balance: (json['balance'] as num?)?.toDouble(),
        status: json['status'] as String? ?? 'in-house',
        folioBalanced: json['folio_balanced'] as bool? ?? false,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Reservation
// ═══════════════════════════════════════════════════════════════════════════

class Reservation {
  final String id;
  final String confirmationNumber;
  final String propertyCode;
  final String guestId;
  final String guestName;
  final DateTime arrivalDate;
  final DateTime departureDate;
  final int nights;
  final int adults;
  final int children;
  final String roomType;
  final String? ratePlanCode;
  final double? rate;
  final String status;
  final String? roomNumber;
  final bool guaranteed;
  final String? guaranteeMethod;
  final List<FolioItem> charges;
  final double balance;
  final List<String> packageCodes;
  final String? specialRequests;
  final DateTime createdAt;

  const Reservation({
    required this.id,
    required this.confirmationNumber,
    required this.propertyCode,
    required this.guestId,
    required this.guestName,
    required this.arrivalDate,
    required this.departureDate,
    required this.nights,
    required this.adults,
    required this.children,
    required this.roomType,
    this.ratePlanCode,
    this.rate,
    required this.status,
    this.roomNumber,
    this.guaranteed = false,
    this.guaranteeMethod,
    this.charges = const [],
    this.balance = 0,
    this.packageCodes = const [],
    this.specialRequests,
    required this.createdAt,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
        id: json['id'] as String,
        confirmationNumber: json['confirmation_number'] as String,
        propertyCode: json['property_code'] as String,
        guestId: json['guest_id'] as String,
        guestName: json['guest_name'] as String,
        arrivalDate: DateTime.parse(json['arrival_date'] as String),
        departureDate: DateTime.parse(json['departure_date'] as String),
        nights: json['nights'] as int? ?? 1,
        adults: json['adults'] as int? ?? 1,
        children: json['children'] as int? ?? 0,
        roomType: json['room_type'] as String,
        ratePlanCode: json['rate_plan_code'] as String?,
        rate: (json['rate'] as num?)?.toDouble(),
        status: json['status'] as String? ?? 'reserved',
        roomNumber: json['room_number'] as String?,
        guaranteed: json['guaranteed'] as bool? ?? false,
        guaranteeMethod: json['guarantee_method'] as String?,
        charges: (json['charges'] as List<dynamic>?)
                ?.map((e) => FolioItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        packageCodes: (json['package_codes'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        specialRequests: json['special_requests'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Room status
// ═══════════════════════════════════════════════════════════════════════════

class RoomStatus {
  final String roomNumber;
  final String roomType;
  final String floor;
  final String housekeepingStatus; // clean, dirty, inspected, out-of-order
  final String frontDeskStatus; // available, occupied, reserved, out-of-order
  final String? guestName;
  final DateTime? lastCleanedAt;

  const RoomStatus({
    required this.roomNumber,
    required this.roomType,
    required this.floor,
    required this.housekeepingStatus,
    required this.frontDeskStatus,
    this.guestName,
    this.lastCleanedAt,
  });

  factory RoomStatus.fromJson(Map<String, dynamic> json) => RoomStatus(
        roomNumber: json['room_number'] as String,
        roomType: json['room_type'] as String,
        floor: json['floor'] as String,
        housekeepingStatus: json['housekeeping_status'] as String,
        frontDeskStatus: json['front_desk_status'] as String,
        guestName: json['guest_name'] as String?,
        lastCleanedAt: json['last_cleaned_at'] != null
            ? DateTime.tryParse(json['last_cleaned_at'] as String)
            : null,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Folio
// ═══════════════════════════════════════════════════════════════════════════

class Folio {
  final String id;
  final String reservationId;
  final String? roomNumber;
  final String guestName;
  final List<FolioItem> items;
  final double charges;
  final double payments;
  final double taxes;
  final double balance;

  const Folio({
    required this.id,
    required this.reservationId,
    this.roomNumber,
    required this.guestName,
    required this.items,
    required this.charges,
    required this.payments,
    required this.taxes,
    required this.balance,
  });

  factory Folio.fromJson(Map<String, dynamic> json) => Folio(
        id: json['id'] as String,
        reservationId: json['reservation_id'] as String,
        roomNumber: json['room_number'] as String?,
        guestName: json['guest_name'] as String,
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => FolioItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        charges: (json['charges'] as num?)?.toDouble() ?? 0,
        payments: (json['payments'] as num?)?.toDouble() ?? 0,
        taxes: (json['taxes'] as num?)?.toDouble() ?? 0,
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
      );
}

class FolioItem {
  final String id;
  final DateTime date;
  final String description;
  final String category; // room, food, beverage, tax, payment, etc.
  final double amount;
  final bool isPayment;
  final String? postedBy;

  const FolioItem({
    required this.id,
    required this.date,
    required this.description,
    required this.category,
    required this.amount,
    this.isPayment = false,
    this.postedBy,
  });

  factory FolioItem.fromJson(Map<String, dynamic> json) => FolioItem(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        description: json['description'] as String,
        category: json['category'] as String,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        isPayment: json['is_payment'] as bool? ?? false,
        postedBy: json['posted_by'] as String?,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Rate plans & schedules
// ═══════════════════════════════════════════════════════════════════════════

class RatePlan {
  final String code;
  final String name;
  final String category; // BAR, Corporate, Group, Package, Promo
  final String rateClass; // Rack, Standard, Negotiated
  final String roomType;
  final double baseRate;
  final String currencyCode;
  final bool active;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> daysOfWeek;
  final bool breakfastIncluded;
  final String? description;

  const RatePlan({
    required this.code,
    required this.name,
    required this.category,
    required this.rateClass,
    required this.roomType,
    required this.baseRate,
    this.currencyCode = 'USD',
    this.active = true,
    this.startDate,
    this.endDate,
    this.daysOfWeek = const [],
    this.breakfastIncluded = false,
    this.description,
  });

  factory RatePlan.fromJson(Map<String, dynamic> json) => RatePlan(
        code: json['code'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        rateClass: json['rate_class'] as String,
        roomType: json['room_type'] as String,
        baseRate: (json['base_rate'] as num?)?.toDouble() ?? 0,
        currencyCode: json['currency_code'] as String? ?? 'USD',
        active: json['active'] as bool? ?? true,
        startDate: json['start_date'] != null
            ? DateTime.tryParse(json['start_date'] as String)
            : null,
        endDate: json['end_date'] != null
            ? DateTime.tryParse(json['end_date'] as String)
            : null,
        daysOfWeek: (json['days_of_week'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        breakfastIncluded: json['breakfast_included'] as bool? ?? false,
        description: json['description'] as String?,
      );
}

class RateSchedule {
  final String ratePlanCode;
  final DateTime date;
  final double rate;
  final int available;
  final int sold;
  final String currencyCode;

  const RateSchedule({
    required this.ratePlanCode,
    required this.date,
    required this.rate,
    required this.available,
    required this.sold,
    this.currencyCode = 'USD',
  });

  factory RateSchedule.fromJson(Map<String, dynamic> json) => RateSchedule(
        ratePlanCode: json['rate_plan_code'] as String,
        date: DateTime.parse(json['date'] as String),
        rate: (json['rate'] as num?)?.toDouble() ?? 0,
        available: json['available'] as int? ?? 0,
        sold: json['sold'] as int? ?? 0,
        currencyCode: json['currency_code'] as String? ?? 'USD',
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Blocks & events
// ═══════════════════════════════════════════════════════════════════════════

class Block {
  final String id;
  final String name;
  final String blockType; // Group, Tour, Contract, Alliance
  final String status; // Tentative, Definite, Cancelled
  final DateTime startDate;
  final DateTime endDate;
  final int roomsBlocked;
  final int roomsPicked;
  final double? rate;
  final String? contactName;
  final String? contactPhone;
  final String? cutoffDate;
  final String propertyCode;

  const Block({
    required this.id,
    required this.name,
    required this.blockType,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.roomsBlocked,
    required this.roomsPicked,
    this.rate,
    this.contactName,
    this.contactPhone,
    this.cutoffDate,
    required this.propertyCode,
  });

  factory Block.fromJson(Map<String, dynamic> json) => Block(
        id: json['id'] as String,
        name: json['name'] as String,
        blockType: json['block_type'] as String,
        status: json['status'] as String,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        roomsBlocked: json['rooms_blocked'] as int? ?? 0,
        roomsPicked: json['rooms_picked'] as int? ?? 0,
        rate: (json['rate'] as num?)?.toDouble(),
        contactName: json['contact_name'] as String?,
        contactPhone: json['contact_phone'] as String?,
        cutoffDate: json['cutoff_date'] as String?,
        propertyCode: json['property_code'] as String,
      );
}

class Event {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? room;
  final int? expectedAttendees;
  final String status;
  final String? blockId;

  const Event({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.room,
    this.expectedAttendees,
    required this.status,
    this.blockId,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'] as String,
        title: json['title'] as String,
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: DateTime.parse(json['end_time'] as String),
        room: json['room'] as String?,
        expectedAttendees: json['expected_attendees'] as int?,
        status: json['status'] as String? ?? 'confirmed',
        blockId: json['block_id'] as String?,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Profile
// ═══════════════════════════════════════════════════════════════════════════

class Profile {
  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? mobile;
  final String? addressLine1;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? membershipNumber;
  final String? membershipTier;
  final int totalStays;
  final double lifetimeValue;
  final String? vipCode;
  final List<String> preferences;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.mobile,
    this.addressLine1,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.membershipNumber,
    this.membershipTier,
    this.totalStays = 0,
    this.lifetimeValue = 0,
    this.vipCode,
    this.preferences = const [],
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        mobile: json['mobile'] as String?,
        addressLine1: json['address_line1'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        postalCode: json['postal_code'] as String?,
        country: json['country'] as String?,
        membershipNumber: json['membership_number'] as String?,
        membershipTier: json['membership_tier'] as String?,
        totalStays: json['total_stays'] as int? ?? 0,
        lifetimeValue: (json['lifetime_value'] as num?)?.toDouble() ?? 0,
        vipCode: json['vip_code'] as String?,
        preferences: (json['preferences'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Service request & task (housekeeping / engineering)
// ═══════════════════════════════════════════════════════════════════════════

class ServiceRequest {
  final String id;
  final String type; // housekeeping, engineering, room-service, etc.
  final String? roomNumber;
  final String priority; // low, medium, high, urgent
  final String status; // open, in-progress, completed, cancelled
  final String description;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? assignedTo;

  const ServiceRequest({
    required this.id,
    required this.type,
    this.roomNumber,
    required this.priority,
    required this.status,
    required this.description,
    required this.createdAt,
    this.completedAt,
    this.assignedTo,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) => ServiceRequest(
        id: json['id'] as String,
        type: json['type'] as String,
        roomNumber: json['room_number'] as String?,
        priority: json['priority'] as String,
        status: json['status'] as String,
        description: json['description'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        completedAt: json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'] as String)
            : null,
        assignedTo: json['assigned_to'] as String?,
      );
}

class Task {
  final String id;
  final String title;
  final String type;
  final String? roomNumber;
  final String status;
  final String? assignedTo;
  final DateTime dueAt;
  final DateTime? completedAt;

  const Task({
    required this.id,
    required this.title,
    required this.type,
    this.roomNumber,
    required this.status,
    this.assignedTo,
    required this.dueAt,
    this.completedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        type: json['type'] as String,
        roomNumber: json['room_number'] as String?,
        status: json['status'] as String,
        assignedTo: json['assigned_to'] as String?,
        dueAt: DateTime.parse(json['due_at'] as String),
        completedAt: json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'] as String)
            : null,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Audit log
// ═══════════════════════════════════════════════════════════════════════════

class AuditLog {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String action;
  final String? entityType;
  final String? entityId;
  final String? description;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  const AuditLog({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.action,
    this.entityType,
    this.entityId,
    this.description,
    this.before,
    this.after,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        userId: json['user_id'] as String,
        action: json['action'] as String,
        entityType: json['entity_type'] as String?,
        entityId: json['entity_id'] as String?,
        description: json['description'] as String?,
        before: json['before'] as Map<String, dynamic>?,
        after: json['after'] as Map<String, dynamic>?,
      );

  String get beforeJson => before != null ? jsonEncode(before) : '';
  String get afterJson => after != null ? jsonEncode(after) : '';
}

// ═══════════════════════════════════════════════════════════════════════════
// Report data
// ═══════════════════════════════════════════════════════════════════════════

class ReportData {
  final String reportType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String currencyCode;
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, double> totals;

  const ReportData({
    required this.reportType,
    required this.periodStart,
    required this.periodEnd,
    this.currencyCode = 'USD',
    required this.columns,
    required this.rows,
    this.totals = const {},
  });

  factory ReportData.fromJson(Map<String, dynamic> json) => ReportData(
        reportType: json['report_type'] as String,
        periodStart: DateTime.parse(json['period_start'] as String),
        periodEnd: DateTime.parse(json['period_end'] as String),
        currencyCode: json['currency_code'] as String? ?? 'USD',
        columns: (json['columns'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        rows: (json['rows'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            const [],
        totals: (json['totals'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            ) ??
            const {},
      );
}