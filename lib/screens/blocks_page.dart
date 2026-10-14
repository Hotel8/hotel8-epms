// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

/// Blocks.
///
/// Lists all blocks (group blocks, tour blocks, contract blocks) with
/// filters by status, dates, and block type. Shows rooms blocked vs.
/// picked, block dates, contact info, and cutoff date. Tapping a block
/// opens a detail view with events.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class BlocksPage extends StatefulWidget {
  const BlocksPage({
    super.key,
    required this.client,
    required this.propertyId,
  });

  final PmsBffClient client;
  final String propertyId;

  @override
  State<BlocksPage> createState() => _BlocksPageState();
}

class _BlocksPageState extends State<BlocksPage> {
  late Future<List<Block>> _future;
  String? _status;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _blockType;

  static const _statuses = ['Tentative', 'Definite', 'Cancelled'];
  static const _types = ['Group', 'Tour', 'Contract', 'Alliance'];

  @override
  void initState() {
    super.initState();
    _future = widget.client.getBlocks(propertyId: widget.propertyId);
  }

  void _refresh() {
    setState(() {
      _future = widget.client.getBlocks(propertyId: widget.propertyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Filters ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All')),
                          ..._statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                        ],
                        onChanged: (v) {
                          _status = v;
                          _refresh();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<String>(
                        value: _blockType,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All')),
                          ..._types.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                        ],
                        onChanged: (v) {
                          _blockType = v;
                          _refresh();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: _DateButton(
                        label: 'Start',
                        date: _startDate,
                        onChanged: (d) {
                          _startDate = d;
                          _refresh();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: _DateButton(
                        label: 'End',
                        date: _endDate,
                        onChanged: (d) {
                          _endDate = d;
                          _refresh();
                        },
                      ),
                    ),
                    IconButton.outlined(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refresh,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── List ──
            Expanded(
              child: FutureBuilder<List<Block>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  final blocks = snapshot.data!;
                  if (blocks.isEmpty) {
                    return const Center(child: Text('No blocks found.'));
                  }
                  return ListView.builder(
                    itemCount: blocks.length,
                    itemBuilder: (context, i) {
                      final b = blocks[i];
                      final pickPct = b.roomsBlocked == 0
                          ? 0.0
                          : b.roomsPicked / b.roomsBlocked;
                      final statusColor = <String, Color>{
                        'Tentative': Colors.amber,
                        'Definite': Colors.green,
                        'Cancelled': Colors.red,
                      }[b.status] ??
                          Colors.grey;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.2),
                            child: Text(b.blockType[0]),
                          ),
                          title: Text(b.name),
                          subtitle: Text(
                            '${fmt.format(b.startDate)} – ${fmt.format(b.endDate)} • ${b.roomsPicked}/${b.roomsBlocked} rooms',
                          ),
                          trailing: Chip(
                            label: Text(b.status,
                                style: TextStyle(
                                    fontSize: 11, color: statusColor)),
                            backgroundColor: statusColor.withOpacity(0.1),
                          ),
                          childrenPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Contact: ${b.contactName ?? '-'}'),
                                      Text('Phone: ${b.contactPhone ?? '-'}'),
                                      Text('Cutoff: ${b.cutoffDate ?? '-'}'),
                                      if (b.rate != null)
                                        Text('Rate: \$${b.rate!.toStringAsFixed(2)}'),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text('Pickup: ${(pickPct * 100).round()}%'),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(value: pickPct),
                                      const SizedBox(height: 8),
                                      Text('Picked: ${b.roomsPicked}'),
                                      Text('Blocked: ${b.roomsBlocked}'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FutureBuilder<List<Event>>(
                                future: widget.client.getBlockEvents(
                                  propertyId: widget.propertyId,
                                  blockId: b.id,
                                ).then((items) =>
                                    items.map((m) => Event.fromJson(m)).toList()),
                                builder: (context, evSnap) {
                                  if (evSnap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2));
                                  }
                                  final events = evSnap.data ?? [];
                                  if (events.isEmpty) {
                                    return const Text('No events scheduled.');
                                  }
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: events
                                        .map((e) => ListTile(
                                              dense: true,
                                              leading: const Icon(Icons.event, size: 20),
                                              title: Text(e.title),
                                              subtitle: Text(
                                                '${DateFormat.Hm().format(e.startTime)} – ${DateFormat.Hm().format(e.endTime)} • ${e.room ?? '-'}',
                                              ),
                                              trailing: Text('${e.expectedAttendees ?? '-'} pax'),
                                            ))
                                        .toList(),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  const _DateButton({required this.label, required this.date, required this.onChanged});

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
        child: Text(date == null ? '-' : DateFormat.MMMd().format(date!)),
      ),
    );
  }
}