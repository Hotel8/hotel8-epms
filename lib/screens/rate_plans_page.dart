// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

/// Rate Plans.
///
/// Lists all rate plans for the property with filters by category,
/// rate class, and active status. Shows code, name, category, class,
/// room type, base rate, and active toggle. Tapping a rate plan opens
/// a detail drawer with the rate schedule.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class RatePlansPage extends StatefulWidget {
  const RatePlansPage({
    super.key,
    required this.client,
    required this.propertyId,
  });

  final PmsBffClient client;
  final String propertyId;

  @override
  State<RatePlansPage> createState() => _RatePlansPageState();
}

class _RatePlansPageState extends State<RatePlansPage> {
  late Future<List<RatePlan>> _future;
  String? _category;
  String? _rateClass;
  bool? _active;

  static const _categories = ['BAR', 'Corporate', 'Group', 'Package', 'Promo'];
  static const _classes = ['Rack', 'Standard', 'Negotiated'];

  @override
  void initState() {
    super.initState();
    _future = widget.client.getRatePlans(propertyId: widget.propertyId);
  }

  void _refresh() {
    setState(() {
      _future = widget.client.getRatePlans(propertyId: widget.propertyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
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
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All')),
                          ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                        ],
                        onChanged: (v) {
                          _category = v;
                          _refresh();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _rateClass,
                        decoration: const InputDecoration(
                          labelText: 'Rate Class',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All')),
                          ..._classes.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                        ],
                        onChanged: (v) {
                          _rateClass = v;
                          _refresh();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<bool>(
                        value: _active,
                        decoration: const InputDecoration(
                          labelText: 'Active',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(value: true, child: Text('Active')),
                          DropdownMenuItem(value: false, child: Text('Inactive')),
                        ],
                        onChanged: (v) {
                          _active = v;
                          _refresh();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
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
              child: FutureBuilder<List<RatePlan>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  final plans = snapshot.data!;
                  if (plans.isEmpty) {
                    return const Center(child: Text('No rate plans found.'));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Code')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Class')),
                        DataColumn(label: Text('Room Type')),
                        DataColumn(label: Text('Base Rate'), numeric: true),
                        DataColumn(label: Text('Breakfast')),
                        DataColumn(label: Text('Active')),
                      ],
                      rows: plans.map((rp) {
                        return DataRow(
                          onSelectChanged: (_) => _showSchedule(rp),
                          cells: [
                            DataCell(Text(rp.code)),
                            DataCell(Text(rp.name)),
                            DataCell(Text(rp.category)),
                            DataCell(Text(rp.rateClass)),
                            DataCell(Text(rp.roomType)),
                            DataCell(Text(fmt.format(rp.baseRate))),
                            DataCell(Icon(rp.breakfastIncluded
                                ? Icons.restaurant
                                : Icons.close)),
                            DataCell(Icon(rp.active ? Icons.check : Icons.block)),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSchedule(RatePlan rp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            AppBar(
              title: Text('${rp.code} - ${rp.name}'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: widget.client.getRateSchedule(
                  propertyId: widget.propertyId,
                  ratePlanId: rp.code,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  final items =
                      snapshot.data!['items'] as List<dynamic>? ?? [];
                  final schedule = items
                      .map((e) =>
                          RateSchedule.fromJson(e as Map<String, dynamic>))
                      .toList();
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: schedule.length,
                    itemBuilder: (context, i) {
                      final s = schedule[i];
                      return ListTile(
                        title: Text(DateFormat.yMMMd().format(s.date)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\$${s.rate.toStringAsFixed(2)}'),
                            const SizedBox(width: 16),
                            Text('${s.sold}/${s.available + s.sold}'),
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