// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

/// Arrivals List.
///
/// Shows today's due-in reservations with a "Check-in" action button on
/// each row. Filterable by pre-registered status and VIP.

import 'package:flutter/material.dart';

import '../bff_client.dart';
import '../models.dart';
import 'check_in_page.dart';

class ArrivalsPage extends StatefulWidget {
  const ArrivalsPage({
    super.key,
    required this.client,
    required this.propertyId,
  });

  final PmsBffClient client;
  final String propertyId;

  @override
  State<ArrivalsPage> createState() => _ArrivalsPageState();
}

class _ArrivalsPageState extends State<ArrivalsPage> {
  late Future<List<Reservation>> _future;
  bool _preRegOnly = false;
  bool _vipOnly = false;

  @override
  void initState() {
    super.initState();
    _future = widget.client
        .getArrivals(propertyId: widget.propertyId);
  }

  void _refresh() {
    setState(() {
      _future =
          widget.client.getArrivals(propertyId: widget.propertyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Arrivals'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Column(
        children: [
          // ── Filters ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Pre-registered'),
                  selected: _preRegOnly,
                  onSelected: (v) => setState(() => _preRegOnly = v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('VIP'),
                  selected: _vipOnly,
                  onSelected: (v) => setState(() => _vipOnly = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Reservation>>(
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
                final arrivals = snapshot.data!;
                if (arrivals.isEmpty) {
                  return const Center(child: Text('No arrivals found.'));
                }
                return ListView.builder(
                  itemCount: arrivals.length,
                  itemBuilder: (context, i) {
                    final a = arrivals[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(a.guestName.isNotEmpty
                              ? a.guestName[0].toUpperCase()
                              : '?'),
                        ),
                        title: Row(
                          children: [
                            Text(a.guestName),
                          ],
                        ),
                        subtitle: Text(
                          'Conf ${a.confirmationNumber} • ${a.roomType} • ${a.nights} nights • \$${a.rate?.toStringAsFixed(2) ?? '-'}',
                        ),
                        trailing: FilledButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CheckInPage(
                                client: widget.client,
                                propertyId: widget.propertyId,
                                reservationId: a.id,
                                guestName: a.guestName,
                              ),
                            ),
                          ),
                          child: const Text('Check-in'),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CheckInPage(
                              client: widget.client,
                              propertyId: widget.propertyId,
                              reservationId: a.id,
                              guestName: a.guestName,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}