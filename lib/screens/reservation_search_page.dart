// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

/// Reservation Search.
///
/// Search by guest name, confirmation number, arrival/departure dates,
/// status, or room number. Results shown in a data table; tapping a row
/// opens the reservation detail page.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';
import 'reservation_detail_page.dart';

class ReservationSearchPage extends StatefulWidget {
  const ReservationSearchPage({
    super.key,
    required this.client,
    required this.propertyId,
  });

  final PmsBffClient client;
  final String propertyId;

  @override
  State<ReservationSearchPage> createState() => _ReservationSearchPageState();
}

class _ReservationSearchPageState extends State<ReservationSearchPage> {
  final _nameCtrl = TextEditingController();
  final _confCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  DateTime? _arrival;
  DateTime? _departure;
  String _status = '';
  List<Reservation> _results = [];
  bool _loading = false;

  static const _statusOptions = ['', 'reserved', 'confirmed', 'in-house', 'checked-out', 'cancelled', 'no-show'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _confCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    setState(() => _loading = true);
    try {
      _results = await widget.client.searchReservations(
        propertyId: widget.propertyId,
        lastName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        status: _status.isEmpty ? null : _status,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      _results = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Filter bar ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Guest Name',
                              prefixIcon: Icon(Icons.person_outline, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _doSearch(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _confCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Confirmation #',
                              prefixIcon: Icon(Icons.confirmation_number, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _doSearch(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _roomCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Room #',
                              prefixIcon: Icon(Icons.bed, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _doSearch(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _statusOptions
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.isEmpty ? 'All' : s),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _status = v ?? ''),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DateField(
                            label: 'Arrival',
                            date: _arrival,
                            onChanged: (d) => setState(() => _arrival = d),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DateField(
                            label: 'Departure',
                            date: _departure,
                            onChanged: (d) => setState(() => _departure = d),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _loading ? null : _doSearch,
                          icon: const Icon(Icons.search),
                          label: const Text('Search'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Results ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text('No results — adjust filters and search.',
                              style: theme.textTheme.bodyLarge),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Conf #')),
                              DataColumn(label: Text('Guest')),
                              DataColumn(label: Text('Arrival')),
                              DataColumn(label: Text('Depart')),
                              DataColumn(label: Text('Nights')),
                              DataColumn(label: Text('Room')),
                              DataColumn(label: Text('Rate')),
                              DataColumn(label: Text('Status')),
                            ],
                            rows: _results.map((r) {
                              return DataRow(
                                onSelectChanged: (_) => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReservationDetailPage(
                                      client: widget.client,
                                      propertyId: widget.propertyId,
                                      reservationId: r.id,
                                    ),
                                  ),
                                ),
                                cells: [
                                  DataCell(Text(r.confirmationNumber)),
                                  DataCell(Text(r.guestName)),
                                  DataCell(Text(
                                      DateFormat.MMMd().format(r.arrivalDate))),
                                  DataCell(Text(DateFormat.MMMd()
                                      .format(r.departureDate))),
                                  DataCell(Text('${r.nights}')),
                                  DataCell(Text(r.roomNumber ?? '-')),
                                  DataCell(Text(r.rate != null
                                      ? '\$${r.rate!.toStringAsFixed(2)}'
                                      : '-')),
                                  DataCell(_StatusChip(r.status)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({
    required this.label,
    required this.date,
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
          firstDate: DateTime(today.year - 2),
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
        child: Text(date == null
            ? '-'
            : DateFormat.MMMd().format(date!)),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

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
      label: Text(status, style: const TextStyle(fontSize: 11)),
      backgroundColor: c.withOpacity(0.15),
      side: BorderSide(color: c.withOpacity(0.3)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}