// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

/// Create Reservation.
///
/// A multi-step form: (1) Guest Profile, (2) Dates, (3) Room Type &
/// Rate Plan, (4) Packages, (5) Payment/Guarantee. On completion calls
/// `POST /proxy/pms/rsv/v1/.../reservations` and navigates to the
/// reservation detail page.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';
import 'reservation_detail_page.dart';

class CreateReservationPage extends StatefulWidget {
  const CreateReservationPage({
    super.key,
    required this.client,
    required this.propertyId,
  });

  final PmsBffClient client;
  final String propertyId;

  @override
  State<CreateReservationPage> createState() => _CreateReservationPageState();
}

class _CreateReservationPageState extends State<CreateReservationPage> {
  int _step = 0;

  // Step 1 — guest
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Step 2 — dates
  DateTime? _arrival;
  DateTime? _departure;
  int _adults = 1;
  int _children = 0;

  // Step 3 — room & rate
  String _roomType = '';
  String _ratePlan = '';
  List<RatePlan> _ratePlans = [];
  double? _rate;

  // Step 4 — packages
  final _selectedPackages = <String>{};

  // Step 5 — payment
  String _guaranteeMethod = 'credit-card';
  final _ccNumberCtrl = TextEditingController();
  final _ccNameCtrl = TextEditingController();
  final _specialCtrl = TextEditingController();

  bool _loading = false;

  static const _roomTypes = ['STD', 'DLX', 'SUITE', 'EXEC', 'KING'];
  static const _guaranteeMethods = ['credit-card', 'debit-card', 'deposit', 'cash', 'company'];

  @override
  void initState() {
    super.initState();
    _loadRatePlans();
  }

  Future<void> _loadRatePlans() async {
    try {
      _ratePlans = await widget.client
          .getRatePlans(propertyId: widget.propertyId);
      if (mounted) setState(() {});
    } catch (_) {
      // Silently continue; user can still type a rate plan code.
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _ccNumberCtrl.dispose();
    _ccNameCtrl.dispose();
    _specialCtrl.dispose();
    super.dispose();
  }

  bool get _stepValid {
    switch (_step) {
      case 0:
        return _firstNameCtrl.text.trim().isNotEmpty &&
            _lastNameCtrl.text.trim().isNotEmpty;
      case 1:
        return _arrival != null && _departure != null && _departure!.isAfter(_arrival!);
      case 2:
        return _roomType.isNotEmpty && _ratePlan.isNotEmpty;
      default:
        return true;
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final nights = _departure!.difference(_arrival!).inDays;
      final body = <String, dynamic>{
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'arrival_date': _arrival!.toIso8601String().split('T').first,
        'departure_date': _departure!.toIso8601String().split('T').first,
        'nights': nights,
        'adults': _adults,
        'children': _children,
        'room_type': _roomType,
        'rate_plan_code': _ratePlan,
        if (_rate != null) 'rate': _rate,
        'package_codes': _selectedPackages.toList(),
        'guaranteed': true,
        'guarantee_method': _guaranteeMethod,
        if (_specialCtrl.text.trim().isNotEmpty)
          'special_requests': _specialCtrl.text.trim(),
      };
      final rsv = await widget.client.createReservation(
        propertyId: widget.propertyId,
        body: body,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ReservationDetailPage(
            client: widget.client,
            propertyId: widget.propertyId,
            reservationId: rsv.id,
          ),
        ));
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
    return Scaffold(
      appBar: AppBar(title: const Text('New Reservation')),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () {
          if (!_stepValid) return;
          if (_step < 4) {
            setState(() => _step++);
          } else {
            _submit();
          }
        },
        onStepCancel: () {
          if (_step > 0) {
            setState(() => _step--);
          } else {
            Navigator.of(context).pop();
          }
        },
        onStepTapped: (i) => setState(() => _step = i),
        controlsBuilder: (context, details) {
          return Row(
            children: [
              FilledButton(
                onPressed: _loading ? null : details.onStepContinue,
                child: Text(_step < 4 ? 'Next' : 'Create Reservation'),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
              if (_loading) const SizedBox(width: 8, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          );
        },
        steps: [
          // ── Step 1: Guest ──
          Step(
            title: const Text('Guest Profile'),
            subtitle: const Text('Primary guest details'),
            isActive: _step >= 0,
            content: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'First Name *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lastNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Last Name *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, size: 18),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          // ── Step 2: Dates ──
          Step(
            title: const Text('Dates & Guests'),
            subtitle: const Text('Arrival, departure, occupancy'),
            isActive: _step >= 1,
            content: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Arrival *',
                        date: _arrival,
                        first: DateTime.now(),
                        onChanged: (d) => setState(() {
                          _arrival = d;
                          if (_departure != null &&
                              _departure!.isBefore(d!.add(const Duration(days: 1)))) {
                            _departure = d.add(const Duration(days: 1));
                          }
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateField(
                        label: 'Departure *',
                        date: _departure,
                        first: _arrival?.add(const Duration(days: 1)),
                        onChanged: (d) => setState(() => _departure = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Counter(
                        label: 'Adults',
                        value: _adults,
                        min: 1,
                        onChanged: (v) => setState(() => _adults = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Counter(
                        label: 'Children',
                        value: _children,
                        onChanged: (v) => setState(() => _children = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nights: ${(_arrival != null && _departure != null) ? _departure!.difference(_arrival!).inDays : 0}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Step 3: Room & Rate ──
          Step(
            title: const Text('Room & Rate'),
            subtitle: const Text('Room type and rate plan'),
            isActive: _step >= 2,
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _roomType.isEmpty ? null : _roomType,
                  decoration: const InputDecoration(
                    labelText: 'Room Type *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _roomTypes
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => _roomType = v ?? ''),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _ratePlan.isEmpty ? null : _ratePlan,
                  decoration: const InputDecoration(
                    labelText: 'Rate Plan *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _ratePlans
                      .map((rp) => DropdownMenuItem(
                            value: rp.code,
                            child: Text('${rp.code} — ${rp.name} (${rp.baseRate})'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _ratePlan = v ?? '';
                      final rp = _ratePlans.firstWhere(
                        (r) => r.code == v,
                        orElse: () => _ratePlans.first,
                      );
                      _rate = rp.baseRate;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Rate (override)',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => _rate = double.tryParse(v),
                  controller: TextEditingController(
                      text: _rate != null ? _rate!.toStringAsFixed(2) : ''),
                ),
              ],
            ),
          ),
          // ── Step 4: Packages ──
          Step(
            title: const Text('Packages'),
            subtitle: const Text('Optional add-ons'),
            isActive: _step >= 3,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  value: _selectedPackages.contains('BREAKFAST'),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selectedPackages.add('BREAKFAST');
                    } else {
                      _selectedPackages.remove('BREAKFAST');
                    }
                  }),
                  title: const Text('Breakfast'),
                  dense: true,
                ),
                CheckboxListTile(
                  value: _selectedPackages.contains('PARKING'),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selectedPackages.add('PARKING');
                    } else {
                      _selectedPackages.remove('PARKING');
                    }
                  }),
                  title: const Text('Parking'),
                  dense: true,
                ),
                CheckboxListTile(
                  value: _selectedPackages.contains('SPA'),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selectedPackages.add('SPA');
                    } else {
                      _selectedPackages.remove('SPA');
                    }
                  }),
                  title: const Text('Spa Credit'),
                  dense: true,
                ),
              ],
            ),
          ),
          // ── Step 5: Payment ──
          Step(
            title: const Text('Payment Guarantee'),
            subtitle: const Text('Guarantee method'),
            isActive: _step >= 4,
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _guaranteeMethod,
                  decoration: const InputDecoration(
                    labelText: 'Guarantee Method',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _guaranteeMethods
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setState(() => _guaranteeMethod = v ?? _guaranteeMethod),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ccNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Card Number',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ccNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cardholder Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _specialCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Special Requests',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final DateTime? first;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({
    required this.label,
    required this.date,
    this.first,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final today = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? today,
          firstDate: first ?? DateTime(today.year - 1),
          lastDate: DateTime(today.year + 2),
        );
        onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Text(date == null ? '-' : DateFormat.MMMd().format(date!)),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  const _Counter({
    required this.label,
    required this.value,
    this.min = 0,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}