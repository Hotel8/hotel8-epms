// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

/// Check-in Flow.
///
/// Multi-step check-in: (1) Find reservation (by conf # or guest name),
/// (2) Pre-register / verify guest details, (3) Assign room, (4) Complete
/// check-in. Calls `POST /proxy/pms/rsv/v1/.../reservations/{id}/check-in`.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class CheckInPage extends StatefulWidget {
  const CheckInPage({
    super.key,
    required this.client,
    required this.propertyId,
    this.reservationId,
    this.guestName,
  });

  final PmsBffClient client;
  final String propertyId;
  final String? reservationId;
  final String? guestName;

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  int _step = 0;
  final _searchCtrl = TextEditingController();
  Reservation? _reservation;
  List<RoomStatus> _availableRooms = [];
  String? _selectedRoom;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.reservationId != null) {
      _step = 1;
      _loadReservation();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final results = await widget.client.searchReservations(
        propertyId: widget.propertyId,
        lastName: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No reservations found.')));
        }
        return;
      }
      setState(() {
        _reservation = results.first;
        _step = 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReservation() async {
    if (widget.reservationId == null) return;
    setState(() => _loading = true);
    try {
      _reservation = await widget.client.getReservation(
        propertyId: widget.propertyId,
        reservationId: widget.reservationId!,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRooms() async {
    setState(() => _loading = true);
    try {
      final rooms = await widget.client.getRoomStatuses(
        propertyId: widget.propertyId,
      );
      _availableRooms = rooms
          .map((m) => RoomStatus.fromJson(m))
          .where((r) => r.frontDeskStatus == 'available')
          .toList();
    } catch (e) {
      _availableRooms = [];
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _preRegister() async {
    if (_reservation == null) return;
    setState(() => _loading = true);
    try {
      await widget.client.preRegister(
        propertyId: widget.propertyId,
        reservationId: _reservation!.id,
      );
      setState(() => _step = 2);
      _loadRooms();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeCheckIn() async {
    if (_reservation == null || _selectedRoom == null) return;
    setState(() => _loading = true);
    try {
      await widget.client.checkIn(
        propertyId: widget.propertyId,
        reservationId: _reservation!.id,
        roomNumber: _selectedRoom!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Check-in complete!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              currentStep: _step,
              onStepContinue: () {
                switch (_step) {
                  case 0:
                    _search();
                  case 1:
                    _preRegister();
                  case 2:
                    if (_selectedRoom != null) setState(() => _step = 3);
                }
              },
              onStepCancel: () {
                if (_step > 0) {
                  setState(() => _step--);
                } else {
                  Navigator.of(context).pop();
                }
              },
              controlsBuilder: (context, details) {
                final labels = ['Search', 'Pre-register', 'Assign Room', ''];
                return Row(
                  children: [
                    if (_step < 3)
                      FilledButton(onPressed: details.onStepContinue, child: Text(labels[_step])),
                    if (_step == 3)
                      FilledButton(onPressed: _completeCheckIn, child: const Text('Complete Check-in')),
                    const SizedBox(width: 8),
                    TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
                  ],
                );
              },
              steps: [
                Step(
                  title: const Text('Find Reservation'),
                  isActive: _step >= 0,
                  content: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name or Confirmation #',
                      prefixIcon: Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                Step(
                  title: const Text('Pre-register'),
                  isActive: _step >= 1,
                  content: _reservation == null
                      ? const Text('No reservation loaded.')
                      : Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_reservation!.guestName,
                                    style: theme.textTheme.titleMedium),
                                Text('Conf: ${_reservation!.confirmationNumber}'),
                                Text(
                                    'Dates: ${fmt.format(_reservation!.arrivalDate)} → ${fmt.format(_reservation!.departureDate)}'),
                                Text('Room Type: ${_reservation!.roomType}'),
                                Text(
                                    'Guests: ${_reservation!.adults} adults, ${_reservation!.children} children'),
                                if (_reservation!.specialRequests != null)
                                  Text('Notes: ${_reservation!.specialRequests}'),
                              ],
                            ),
                          ),
                        ),
                ),
                Step(
                  title: const Text('Assign Room'),
                  isActive: _step >= 2,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_availableRooms.isEmpty)
                        const Text('Loading available rooms…')
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedRoom,
                          decoration: const InputDecoration(
                            labelText: 'Room Number',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _availableRooms
                              .map((r) => DropdownMenuItem(
                                    value: r.roomNumber,
                                    child: Text(
                                        'Room ${r.roomNumber} (${r.roomType}, Floor ${r.floor})'),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedRoom = v),
                        ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Complete'),
                  isActive: _step >= 3,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Guest: ${_reservation?.guestName}'),
                      Text('Room: $_selectedRoom'),
                      const SizedBox(height: 8),
                      const Text('Ready to complete check-in.'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}