// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

/// Front-Desk Dashboard.
///
/// Shows today's arrivals/departures counts, an occupancy gauge,
/// housekeeping status breakdown, revenue KPIs (rooms, F&B, other, ADR,
/// RevPAR), and quick action buttons (Check-in, Check-out, New
/// Reservation, Room Status).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';
import 'arrivals_page.dart';
import 'check_in_page.dart';
import 'check_out_page.dart';
import 'create_reservation_page.dart';
import 'room_status_grid_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.client,
    required this.propertyId,
  });

  final PmsBffClient client;
  final String propertyId;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Dashboard> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.client.getDashboard(propertyId: widget.propertyId);
  }

  void _refresh() {
    setState(() {
      _future =
          widget.client.getDashboard(propertyId: widget.propertyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      body: FutureBuilder<Dashboard>(
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
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString()),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }

          final d = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Business date header ──
                Row(
                  children: [
                    Text(
                      'Business Date: ${DateFormat.yMMMd().format(d.businessDate)}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refresh,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ── Quick actions ──
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Check-in'),
                      avatar: const Icon(Icons.login),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CheckInPage(
                            client: widget.client,
                            propertyId: widget.propertyId,
                          ),
                        ),
                      ),
                    ),
                    ActionChip(
                      label: const Text('Check-out'),
                      avatar: const Icon(Icons.logout),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CheckOutPage(
                            client: widget.client,
                            propertyId: widget.propertyId,
                          ),
                        ),
                      ),
                    ),
                    ActionChip(
                      label: const Text('New Reservation'),
                      avatar: const Icon(Icons.add_circle_outline),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateReservationPage(
                            client: widget.client,
                            propertyId: widget.propertyId,
                          ),
                        ),
                      ),
                    ),
                    ActionChip(
                      label: const Text('Room Status'),
                      avatar: const Icon(Icons.grid_view),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoomStatusGridPage(
                            client: widget.client,
                            propertyId: widget.propertyId,
                          ),
                        ),
                      ),
                    ),
                    ActionChip(
                      label: const Text('Arrivals'),
                      avatar: const Icon(Icons.flight_land),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ArrivalsPage(
                            client: widget.client,
                            propertyId: widget.propertyId,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Arrivals / Departures / In-house ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _CountCard(
                        title: 'Arrivals',
                        icon: Icons.flight_land,
                        color: Colors.green,
                        expected: d.arrivalsExpected,
                        done: d.arrivalsCheckedIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CountCard(
                        title: 'Departures',
                        icon: Icons.flight_takeoff,
                        color: Colors.orange,
                        expected: d.departuresExpected,
                        done: d.departuresCheckedOut,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoCard(
                        title: 'In-House Guests',
                        icon: Icons.bedroom_parent,
                        color: Colors.blue,
                        value: '${d.inHouseGuests}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Occupancy gauge ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Occupancy',
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 120,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 120,
                                            height: 120,
                                            child: CircularProgressIndicator(
                                              value: d.occupancyPercent / 100,
                                              strokeWidth: 12,
                                              backgroundColor:
                                                  theme.colorScheme.surfaceContainerHighest,
                                            ),
                                          ),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${d.occupancyPercent}%',
                                                style: theme.textTheme.headlineSmall,
                                              ),
                                              Text(
                                                '${d.availableRooms} avail / ${d.totalRooms} total',
                                                style: theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Housekeeping',
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              _HkRow(
                                  label: 'Clean',
                                  count: d.housekeeping.clean,
                                  color: Colors.green),
                              _HkRow(
                                  label: 'Dirty',
                                  count: d.housekeeping.dirty,
                                  color: Colors.red),
                              _HkRow(
                                  label: 'Inspected',
                                  count: d.housekeeping.inspected,
                                  color: Colors.teal),
                              _HkRow(
                                  label: 'Turndown',
                                  count: d.housekeeping.turndown,
                                  color: Colors.purple),
                              _HkRow(
                                  label: 'Out of Order',
                                  count: d.housekeeping.outOfOrder,
                                  color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Revenue KPIs ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Revenue KPIs', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount:
                              MediaQuery.of(context).size.width > 900 ? 4 : 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 2.5,
                          children: [
                            _KpiTile('Room', fmt.format(d.roomRevenue), Colors.blue),
                            _KpiTile('Food', fmt.format(d.foodRevenue), Colors.amber),
                            _KpiTile('Beverage', fmt.format(d.beverageRevenue), Colors.orange),
                            _KpiTile('Other', fmt.format(d.otherRevenue), Colors.teal),
                            _KpiTile('Total', fmt.format(d.totalRevenue), Colors.green),
                            _KpiTile('ADR', fmt.format(d.adr), Colors.indigo),
                            _KpiTile('RevPAR', fmt.format(d.revpar), Colors.deepPurple),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int expected;
  final int done;

  const _CountCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.expected,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = expected - done;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Stat('Expected', '$expected'),
                _Stat('Done', '$done'),
                _Stat('Remaining', '$remaining'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: expected == 0 ? 0 : done / expected,
              backgroundColor: color.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String value;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _HkRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _HkRow({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          CircleAvatar(radius: 6, backgroundColor: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('$count',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}