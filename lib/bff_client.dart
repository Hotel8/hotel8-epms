// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

// PMS BFF client — calls the BFF proxy endpoints which delegate to
// the Hotel8:PMS service.
//
// All API paths match the actual PMS server routes:
//   /proxy/hotel8-pms/v1/properties/{propertyId}/...
//
// Uses the http package with credentials: 'include' for cookie-based
// BFF session management. On web, the browser automatically sends the
// BFF session cookie for same-origin requests.

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Exception thrown by the BFF client when a request fails.
class BffException implements Exception {
  final int statusCode;
  final String message;
  BffException(this.statusCode, this.message);
  @override
  String toString() => 'BffException($statusCode): $message';
}

class PmsBffClient {
  PmsBffClient({required this.bffBaseUrl, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final String bffBaseUrl;
  final http.Client _httpClient;

  String _path(String p) => bffBaseUrl.isEmpty ? p : '$bffBaseUrl$p';

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Raw JSON GET — used by the RFW page host (rfw/ops_page.dart).
  Future<Map<String, dynamic>> getRawJson(String path,
      [Map<String, String>? query]) => _getJson(path, query);

  /// Raw JSON POST — used by the RFW page host (rfw/ops_page.dart).
  Future<Map<String, dynamic>> postRawJson(String path, Map<String, dynamic> body) =>
      _postJson(path, body);

  Future<Map<String, dynamic>> _getJson(String path,
      [Map<String, String>? query]) async {
    final uri = Uri.parse(_path(path));
    final resolved = query == null ? uri : uri.replace(queryParameters: query);
    final resp = await _httpClient.get(resolved, headers: _headers());
    return _handle(resp);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await _httpClient.post(
      Uri.parse(_path(path)),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> _handle(http.Response resp) async {
    final body = resp.body.isEmpty ? '{}' : resp.body;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    String message;
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      message =
          decoded['message'] as String? ?? decoded['error'] as String? ?? body;
    } catch (_) {
      message = body;
    }
    throw BffException(resp.statusCode, message);
  }

  void close() {
    _httpClient.close();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Dashboard
  // ═════════════════════════════════════════════════════════════════════════

  Future<Dashboard> getDashboard({required String propertyId}) async {
    final json = await _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/reports/occupancy');
    return Dashboard.fromJson(json);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Reservations
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<Reservation>> searchReservations({
    required String propertyId,
    String? lastName,
    String? status,
  }) async {
    final query = <String, String>{};
    if (lastName != null) query['last_name'] = lastName;
    if (status != null) query['status'] = status;
    final json = await _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/reservations',
        query);
    final items = json['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => Reservation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Reservation> getReservation({
    required String propertyId,
    required String reservationId,
  }) async {
    final json = await _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/reservations/$reservationId');
    return Reservation.fromJson(json);
  }

  Future<Reservation> createReservation({
    required String propertyId,
    required Map<String, dynamic> body,
  }) async {
    final json = await _postJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/reservations', body);
    return Reservation.fromJson(json);
  }

  Future<void> cancelReservation({
    required String propertyId,
    required String reservationId,
  }) async {
    await _postJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/reservations/$reservationId/cancel',
        {});
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Front Desk
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> preCheckIn({
    required String propertyId,
    required String reservationId,
  }) async {
    await _postJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/reservations/$reservationId/pre-check-in',
        {});
  }

  Future<void> checkIn({
    required String propertyId,
    required String reservationId,
    String? roomNumber,
  }) async {
    final body = <String, dynamic>{};
    if (roomNumber != null) body['room_number'] = roomNumber;
    await _postJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/reservations/$reservationId/check-in',
        body);
  }

  Future<void> checkOut({
    required String propertyId,
    required String reservationId,
  }) async {
    await _postJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/reservations/$reservationId/check-out',
        {});
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Housekeeping
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getRoomStatuses({
    required String propertyId,
  }) async {
    final json = await _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/housekeeping');
    final items = json['items'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  Future<void> updateRoomStatus({
    required String propertyId,
    required String roomNumber,
    String? housekeepingStatus,
    String? frontOfficeStatus,
  }) async {
    final body = <String, dynamic>{};
    if (housekeepingStatus != null) body['housekeeping_status'] = housekeepingStatus;
    if (frontOfficeStatus != null) body['front_office_status'] = frontOfficeStatus;
    await _postJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/housekeeping/$roomNumber',
        body);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Cashiering
  // ═════════════════════════════════════════════════════════════════════════

  Future<Folio> getFolio({
    required String propertyId,
    required String reservationId,
  }) async {
    final json = await _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/reservations/$reservationId/folio');
    return Folio.fromJson(json);
  }

  Future<void> postCharge({
    required String propertyId,
    required String reservationId,
    required String chargeCode,
    required double amount,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'charge_code': chargeCode,
      'amount': amount.toString(),
      if (description != null) 'description': description,
    };
    await _postJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/reservations/$reservationId/charges',
        body);
  }

  Future<void> postPayment({
    required String propertyId,
    required String reservationId,
    required String paymentCode,
    required double amount,
  }) async {
    final body = <String, dynamic>{
      'payment_code': paymentCode,
      'amount': amount.toString(),
    };
    await _postJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/reservations/$reservationId/payments',
        body);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Rate Plans
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<RatePlan>> listRatePlans({required String propertyId}) async {
    final json = await _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/rate-plans');
    final items = json['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => RatePlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Blocks
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<Block>> listBlocks({required String propertyId}) async {
    final json = await _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/blocks');
    final items = json['items'] as List<dynamic>? ?? [];
    return items.map((e) => Block.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Profiles
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<Profile>> listProfiles({
    required String propertyId,
    String? lastName,
  }) async {
    final query = <String, String>{};
    if (lastName != null) query['last_name'] = lastName;
    final json = await _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/profiles',
        query);
    final items = json['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => Profile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Back Office / EOD
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> endOfDay({required String propertyId}) async {
    await _postJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/end-of-day', {});
  }

  Future<Map<String, dynamic>> getAuditLog({required String propertyId}) async {
    return _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/audit-log');
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Availability
  // ═════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> searchAvailability({
    required String propertyId,
    required String arrivalDate,
    required String departureDate,
    int adults = 2,
    int rooms = 1,
  }) async {
    return _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/availability',
        {
          'arrival_date': arrivalDate,
          'departure_date': departureDate,
          'number_of_adults': adults.toString(),
          'number_of_rooms': rooms.toString(),
        });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Inventory
  // ═════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getInventory({
    required String propertyId,
    required String startDate,
    required String endDate,
  }) async {
    return _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/inventory',
        {
          'start_date': startDate,
          'end_date': endDate,
        });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Arrivals (in-house guests)
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<Reservation>> getArrivals({
    required String propertyId,
    String? status,
  }) async {
    return searchReservations(propertyId: propertyId, status: status ?? 'DUE_IN');
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Pre-register (alias for preCheckIn)
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> preRegister({
    required String propertyId,
    required String reservationId,
  }) async {
    await preCheckIn(propertyId: propertyId, reservationId: reservationId);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Split reservation
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> splitReservation({
    required String propertyId,
    required String reservationId,
  }) async {
    await _postJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/reservations/$reservationId/split',
        {});
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Rate plans (aliases)
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<RatePlan>> getRatePlans({required String propertyId}) async {
    return listRatePlans(propertyId: propertyId);
  }

  Future<Map<String, dynamic>> getRateSchedule({
    required String propertyId,
    required String ratePlanId,
  }) async {
    return _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/rate-plans/$ratePlanId/schedules');
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Blocks (aliases)
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<Block>> getBlocks({required String propertyId}) async {
    return listBlocks(propertyId: propertyId);
  }

  Future<List<Map<String, dynamic>>> getBlockEvents({
    required String propertyId,
    required String blockId,
  }) async {
    final json = await _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/events',
        {'block_id': blockId});
    final items = json['items'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Profiles (alias)
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<Profile>> searchProfiles({
    required String propertyId,
    String? lastName,
  }) async {
    return listProfiles(propertyId: propertyId, lastName: lastName);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // EOD (aliases)
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> runEod({required String propertyId}) async {
    await endOfDay(propertyId: propertyId);
  }

  Future<Map<String, dynamic>> getEodStatus({required String propertyId}) async {
    return _getJson(
        '/proxy/hotel8-pms/v1/properties/$propertyId/end-of-day/exceptions');
  }
}