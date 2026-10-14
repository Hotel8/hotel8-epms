// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

/// Reservation Detail.
///
/// Full reservation info with action buttons: Edit, Cancel, Split
/// (multi-room), Check-in (if reserved), Check-out (if in-house), View
/// Folio. Shows guest, dates, room, rate, packages, and charges summary.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';
import 'check_in_page.dart';
import 'check_out_page.dart';
import 'create_reservation_page.dart';
import 'folio_page.dart';

class ReservationDetailPage extends StatefulWidget {
  const ReservationDetailPage({
    super.key,
    required this.client,
    required this.propertyId,
    required this.reservationId,
  });

  final PmsBffClient client;
  final String propertyId;
  final String reservationId;

  @override
  State<ReservationDetailPage> createState() => _ReservationDetailPageState();
}

class _ReservationDetailPageState extends State<ReservationDetailPage> {
  late Future<Reservation> _future;
  final _splitCtrl = TextEditingController(text: '2');

  @override
  void initState() {
    super.initState();
    _future = widget.client.getReservation(
      propertyId: widget.propertyId,
      reservationId: widget.reservationId,
    );
  }

  void _refresh() {
    setState(() {
      _future = widget.client.getReservation(
        propertyId: widget.propertyId,
        reservationId: widget.reservationId,
      );
    });
  }

  Future<void> _cancel(Reservation r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Cancel Reservation'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Dismiss')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Confirm Cancel'),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    try {
      await widget.client.cancelReservation(
        propertyId: widget.propertyId,
        reservationId: r.id,
      );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reservation cancelled.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _split(Reservation r) async {
    final n = int.tryParse(_splitCtrl.text.trim()) ?? 2;
    try {
      await widget.client.splitReservation(
        propertyId: widget.propertyId,
        reservationId: r.id,
      );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reservation split into $n rooms.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(title: const Text('Reservation Detail')),
      body: FutureBuilder<Reservation>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  Text(snapshot.error.toString()),
                  FilledButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }
          final r = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Status header ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _StatusBadge(r.status),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.guestName,
                                style: theme.textTheme.titleLarge),
                            Text('Conf # ${r.confirmationNumber}'),
                          ],
                        ),
                      ),
                      Text('Balance: \$${r.balance.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── Info grid ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stay Details', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _Info('Arrival', fmt.format(r.arrivalDate)),
                          _Info('Departure', fmt.format(r.departureDate)),
                          _Info('Nights', '${r.nights}'),
                          _Info('Adults', '${r.adults}'),
                          _Info('Children', '${r.children}'),
                          _Info('Room Type', r.roomType),
                          _Info('Rate Plan', r.ratePlanCode ?? '-'),
                          _Info('Rate', r.rate != null ? '\$${r.rate!.toStringAsFixed(2)}' : '-'),
                          _Info('Room #', r.roomNumber ?? '-'),
                          _Info('Guarantee', r.guaranteed ? r.guaranteeMethod ?? 'Yes' : 'No'),
                        ],
                      ),
                      if (r.packageCodes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Packages: ${r.packageCodes.join(', ')}'),
                      ],
                      if (r.specialRequests != null && r.specialRequests!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Special Requests: ${r.specialRequests}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── Charges summary ──
              if (r.charges.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recent Charges', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...r.charges.map((c) => ListTile(
                              dense: true,
                              leading: Icon(c.isPayment
                                  ? Icons.payments
                                  : Icons.receipt),
                              title: Text(c.description),
                              subtitle: Text(
                                  '${c.category} • ${DateFormat.MMMd().format(c.date)}'),
                              trailing: Text(
                                '${c.isPayment ? '-' : '+'}\$${c.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: c.isPayment ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // ── Actions ──
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CreateReservationPage(
                        client: widget.client,
                        propertyId: widget.propertyId,
                      ),
                    )),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FolioPage(
                        client: widget.client,
                        propertyId: widget.propertyId,
                        reservationId: r.id,
                        guestName: r.guestName,
                      ),
                    )),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('View Folio'),
                  ),
                  if (r.status == 'reserved' || r.status == 'confirmed')
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CheckInPage(
                          client: widget.client,
                          propertyId: widget.propertyId,
                          reservationId: r.id,
                          guestName: r.guestName,
                        ),
                      )),
                      icon: const Icon(Icons.login),
                      label: const Text('Check-in'),
                    ),
                  if (r.status == 'in-house')
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CheckOutPage(
                          client: widget.client,
                          propertyId: widget.propertyId,
                          reservationId: r.id,
                          guestName: r.guestName,
                        ),
                      )),
                      icon: const Icon(Icons.logout),
                      label: const Text('Check-out'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _split(r),
                    icon: const Icon(Icons.call_split),
                    label: const Text('Split'),
                  ),
                  OutlinedButton.icon(
                    onPressed: r.status == 'cancelled' ? null : () => _cancel(r),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  const _Info(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final colors = <String, Color>{
      'reserved': Colors.blue,
      'confirmed': Colors.teal,
      'in-house': Colors.green,
      'checked-out': Colors.grey,
      'cancelled': Colors.red,
      'no-show': Colors.deepOrange,
    };
    final c = colors[status] ?? Colors.grey;
    return Chip(
      label: Text(status.toUpperCase(),
          style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
      backgroundColor: c.withOpacity(0.1),
      side: BorderSide(color: c),
    );
  }
}