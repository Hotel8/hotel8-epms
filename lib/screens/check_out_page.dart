// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

/// Check-out Flow.
///
/// Multi-step check-out: (1) Retrieve reservation, (2) Review folio,
/// (3) Post any additional charges, (4) Settle balance (payment), (5)
/// Complete check-out. Calls `POST /proxy/pms/rsv/v1/.../check-out`.

import 'package:flutter/material.dart';

import '../bff_client.dart';
import '../models.dart';
import '../app_context.dart';
import '../reauth_gate.dart';

class CheckOutPage extends StatefulWidget {
  const CheckOutPage({
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
  State<CheckOutPage> createState() => _CheckOutPageState();
}

class _CheckOutPageState extends State<CheckOutPage> {
  int _step = 0;
  final _searchCtrl = TextEditingController();
  Reservation? _reservation;
  Folio? _folio;
  bool _loading = false;

  // Post charge
  final _chargeDescCtrl = TextEditingController();
  final _chargeAmtCtrl = TextEditingController();
  String _chargeCategory = 'misc';

  // Settlement
  String _paymentMethod = 'cash';
  final _paymentRefCtrl = TextEditingController();

  static const _categories = ['room', 'food', 'beverage', 'tax', 'parking', 'misc'];
  static const _methods = ['cash', 'card', 'room-charge', 'company'];

  @override
  void initState() {
    super.initState();
    if (widget.reservationId != null) {
      _loadReservation();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _chargeDescCtrl.dispose();
    _chargeAmtCtrl.dispose();
    _paymentRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final results = await widget.client.searchReservations(
        propertyId: widget.propertyId,
        lastName: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        status: 'in-house',
      );
      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No in-house reservations found.')));
        }
        return;
      }
      _reservation = results.first;
      await _loadFolio();
      setState(() => _step = 1);
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
      await _loadFolio();
      setState(() => _step = 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFolio() async {
    if (_reservation == null) return;
    try {
      _folio = await widget.client.getFolio(
        propertyId: widget.propertyId,
        reservationId: _reservation!.id,
      );
    } catch (e) {
      // Folio may not exist yet — that's okay.
    }
  }

  Future<void> _postCharge() async {
    if (_reservation == null) return;
    final amt = double.tryParse(_chargeAmtCtrl.text.trim());
    if (amt == null || _chargeDescCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter description and amount.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.client.postCharge(
        propertyId: widget.propertyId,
        reservationId: _reservation!.id,
        chargeCode: _chargeCategory,
        amount: amt,
        description: _chargeDescCtrl.text.trim(),
      );
      await _loadFolio();
      _chargeDescCtrl.clear();
      _chargeAmtCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _settle() async {
    if (_reservation == null) return;
    // Sensitive-op gate (epms/DESIGN.md §10): folio settlement re-auths the
    // staff session before money moves.
    final ctx = EPmsContextProvider.of(context);
    if (ctx != null &&
        !await ReAuthGate.instance.require(ctx, SensitiveOp.folioSettle, context)) {
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.client.postPayment(
        propertyId: widget.propertyId,
        reservationId: _reservation!.id,
        paymentCode: _paymentMethod,
        amount: _folio?.balance ?? 0,
      );
      await _loadFolio();
      setState(() => _step = 4);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _complete() async {
    if (_reservation == null) return;
    final ctx = EPmsContextProvider.of(context);
    if (ctx != null &&
        !await ReAuthGate.instance.require(ctx, SensitiveOp.checkOut, context)) {
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.client.checkOut(
        propertyId: widget.propertyId,
        reservationId: _reservation!.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Check-out complete!')));
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
    return Scaffold(
      appBar: AppBar(title: const Text('Check-out')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              currentStep: _step,
              onStepTapped: (i) => setState(() => _step = i),
              onStepContinue: () {
                switch (_step) {
                  case 0:
                    _search();
                  case 1:
                    setState(() => _step = 2);
                  case 2:
                    setState(() => _step = 3);
                  case 3:
                    _settle();
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
                final labels = ['Retrieve', 'Review', 'Skip', 'Settle'];
                return Row(
                  children: [
                    if (_step < 4)
                      FilledButton(onPressed: details.onStepContinue, child: Text(labels[_step])),
                    if (_step == 4)
                      FilledButton(onPressed: _complete, child: const Text('Complete Check-out')),
                    const SizedBox(width: 8),
                    TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
                  ],
                );
              },
              steps: [
                Step(
                  title: const Text('Retrieve Reservation'),
                  isActive: _step >= 0,
                  content: widget.reservationId != null && _reservation != null
                      ? Text('Loaded: ${_reservation!.guestName} (Conf ${_reservation!.confirmationNumber})')
                      : TextField(
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
                  title: const Text('Review Folio'),
                  isActive: _step >= 1,
                  content: _folio == null
                      ? const Text('No folio data.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._folio!.items.map((item) => ListTile(
                                  dense: true,
                                  title: Text(item.description),
                                  subtitle: Text(item.category),
                                  trailing: Text(
                                    '${item.isPayment ? '-' : '+'}\$${item.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: item.isPayment ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )),
                            const Divider(),
                            _TotalRow('Charges', _folio!.charges),
                            _TotalRow('Payments', _folio!.payments),
                            _TotalRow('Taxes', _folio!.taxes),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Balance', style: theme.textTheme.titleMedium),
                                Text('\$${_folio!.balance.toStringAsFixed(2)}',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold, color: Colors.red)),
                              ],
                            ),
                          ],
                        ),
                ),
                Step(
                  title: const Text('Post Charges'),
                  isActive: _step >= 2,
                  content: Column(
                    children: [
                      TextField(
                        controller: _chargeDescCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _chargeCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _categories
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) => setState(() => _chargeCategory = v ?? _chargeCategory),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _chargeAmtCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                prefixText: '\$',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            icon: const Icon(Icons.add),
                            onPressed: _postCharge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Settle Balance'),
                  isActive: _step >= 3,
                  content: Column(
                    children: [
                      Text('Balance Due: \$${_folio?.balance.toStringAsFixed(2) ?? '0.00'}',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment Method',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _methods
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) => setState(() => _paymentMethod = v ?? _paymentMethod),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _paymentRefCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Reference (optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Complete'),
                  isActive: _step >= 4,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Guest: ${_reservation?.guestName}'),
                      Text('Room: ${_reservation?.roomNumber ?? '-'}'),
                      if (_folio != null)
                        Text('Balance: \$${_folio!.balance.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      const Text('Ready to complete check-out.'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  const _TotalRow(this.label, this.amount);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('\$${amount.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}