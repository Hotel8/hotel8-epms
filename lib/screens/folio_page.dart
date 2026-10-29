// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

/// Folio View.
///
/// Displays the full folio with charges, payments, taxes, and balance.
/// Includes "Post Charge" and "Post Payment" action dialogs. Can be used
/// as a standalone search page (via the Cashiering nav tab) or embedded
/// within a reservation context.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class FolioSearchPage extends StatefulWidget {
  const FolioSearchPage({
    super.key,
    required this.client,
    required this.propertyId,
  });

  final PmsBffClient client;
  final String propertyId;

  @override
  State<FolioSearchPage> createState() => _FolioSearchPageState();
}

class _FolioSearchPageState extends State<FolioSearchPage> {
  final _searchCtrl = TextEditingController();
  Folio? _folio;
  bool _loading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _loading = true);
    try {
      // Search reservations first, then load folio for first result.
      final results = await widget.client.searchReservations(
        propertyId: widget.propertyId,
        lastName: query,
      );
      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No reservations found.')));
        }
        return;
      }
      final r = results.first;
      _folio = await widget.client.getFolio(
        propertyId: widget.propertyId,
        reservationId: r.id,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Guest name or confirmation #',
                      prefixIcon: Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _loading ? null : _search, child: const Text('Search')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _folio == null
                      ? const Center(child: Text('Search for a guest to view folio.'))
                      : FolioView(
                          client: widget.client,
                          propertyId: widget.propertyId,
                          folio: _folio!,
                          onUpdated: (f) => setState(() => _folio = f),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The folio display - used both in FolioSearchPage and ReservationDetailPage.
class FolioPage extends StatelessWidget {
  const FolioPage({
    super.key,
    required this.client,
    required this.propertyId,
    required this.reservationId,
    this.guestName,
  });

  final PmsBffClient client;
  final String propertyId;
  final String reservationId;
  final String? guestName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Folio - ${guestName ?? reservationId}')),
      body: FutureBuilder<Folio>(
        future: client.getFolio(
            propertyId: propertyId, reservationId: reservationId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          return FolioView(
            client: client,
            propertyId: propertyId,
            folio: snapshot.data!,
            reservationId: reservationId,
          );
        },
      ),
    );
  }
}

class FolioView extends StatefulWidget {
  const FolioView({
    super.key,
    required this.client,
    required this.propertyId,
    required this.folio,
    this.reservationId,
    this.onUpdated,
  });

  final PmsBffClient client;
  final String propertyId;
  final Folio folio;
  final String? reservationId;
  final ValueChanged<Folio>? onUpdated;

  @override
  State<FolioView> createState() => _FolioViewState();
}

class _FolioViewState extends State<FolioView> {
  late Folio _folio = widget.folio;
  bool _loading = false;

  Future<void> _reload() async {
    final rId = widget.reservationId ?? _folio.reservationId;
    setState(() => _loading = true);
    try {
      _folio = await widget.client.getFolio(
          propertyId: widget.propertyId, reservationId: rId);
      widget.onUpdated?.call(_folio);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _postCharge() async {
    final result = await showDialog<FolioItemInput>(
      context: context,
      builder: (ctx) => _ChargeDialog(),
    );
    if (result == null) return;
    setState(() => _loading = true);
    try {
      await widget.client.postCharge(
        propertyId: widget.propertyId,
        reservationId: _folio.reservationId,
        chargeCode: result.category,
        amount: result.amount,
        description: result.description,
      );
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _postPayment() async {
    final result = await showDialog<PaymentInput>(
      context: context,
      builder: (ctx) => _PaymentDialog(balance: _folio.balance),
    );
    if (result == null) return;
    setState(() => _loading = true);
    try {
      await widget.client.postPayment(
        propertyId: widget.propertyId,
        reservationId: _folio.reservationId,
        paymentCode: result.method,
        amount: result.amount,
      );
      _reload();
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
    final fmt = DateFormat.MMMd();
    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(),
        // ── Header ──
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_folio.guestName, style: theme.textTheme.titleMedium),
                  if (_folio.roomNumber != null)
                    Text('Room ${_folio.roomNumber}'),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Balance', style: theme.textTheme.bodySmall),
                  Text('\$${_folio.balance.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        // ── Items table ──
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Description')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Amount'), numeric: true),
              ],
              rows: _folio.items.map((item) {
                return DataRow(
                  cells: [
                    DataCell(Text(fmt.format(item.date))),
                    DataCell(Text(item.description)),
                    DataCell(Text(item.category)),
                    DataCell(Text(
                      '${item.isPayment ? '-' : '+'}\$${item.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: item.isPayment ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(),
        // ── Totals ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _TotalRow('Charges', _folio.charges),
              _TotalRow('Payments', _folio.payments),
              _TotalRow('Taxes', _folio.taxes),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Balance', style: theme.textTheme.titleMedium),
                  Text('\$${_folio.balance.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Actions ──
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _postCharge,
                icon: const Icon(Icons.add),
                label: const Text('Post Charge'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _postPayment,
                icon: const Icon(Icons.payments),
                label: const Text('Post Payment'),
              ),
            ],
          ),
        ),
      ],
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

class FolioItemInput {
  final String description;
  final String category;
  final double amount;
  FolioItemInput(this.description, this.category, this.amount);
}

class _ChargeDialog extends StatefulWidget {
  @override
  State<_ChargeDialog> createState() => _ChargeDialogState();
}

class _ChargeDialogState extends State<_ChargeDialog> {
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  String _category = 'misc';
  static const _categories = ['room', 'food', 'beverage', 'tax', 'parking', 'misc'];

  @override
  void dispose() {
    _descCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Post Charge'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final amt = double.tryParse(_amtCtrl.text.trim());
            if (amt == null || _descCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, FolioItemInput(_descCtrl.text.trim(), _category, amt));
          },
          child: const Text('Post'),
        ),
      ],
    );
  }
}

class PaymentInput {
  final double amount;
  final String method;
  final String? reference;
  PaymentInput(this.amount, this.method, this.reference);
}

class _PaymentDialog extends StatefulWidget {
  final double balance;
  const _PaymentDialog({required this.balance});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _refCtrl = TextEditingController();
  late TextEditingController _amtCtrl;
  String _method = 'cash';
  static const _methods = ['cash', 'card', 'room-charge', 'company'];

  @override
  void initState() {
    super.initState();
    _amtCtrl = TextEditingController(text: widget.balance.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Post Payment'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _method,
              decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
              items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _refCtrl,
              decoration: const InputDecoration(labelText: 'Reference (optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final amt = double.tryParse(_amtCtrl.text.trim());
            if (amt == null) return;
            Navigator.pop(context, PaymentInput(amt, _method, _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim()));
          },
          child: const Text('Post'),
        ),
      ],
    );
  }
}