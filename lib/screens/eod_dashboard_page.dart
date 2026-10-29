// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

/// End of Day Dashboard.
///
/// Shows the EOD processing progress steps, exceptions, and allows
/// triggering the EOD run. Steps typically include: audit folios,
/// roll rates, post room charges, generate reports, close business
/// day.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_context.dart';
import '../bff_client.dart';
import '../reauth_gate.dart';

class EodDashboardPage extends StatefulWidget {
  const EodDashboardPage({
    super.key,
    required this.client,
    required this.propertyId,
  });

  final PmsBffClient client;
  final String propertyId;

  @override
  State<EodDashboardPage> createState() => _EodDashboardPageState();
}

class _EodDashboardPageState extends State<EodDashboardPage> {
  late Future<Map<String, dynamic>> _future;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _future = widget.client.getEodStatus(propertyId: widget.propertyId);
  }

  void _refresh() {
    setState(() {
      _future = widget.client.getEodStatus(propertyId: widget.propertyId);
    });
  }

  Future<void> _runEod() async {
    // Sensitive-op gate (epms/DESIGN.md §10): EOD closes the business date  - 
    // re-auth the staff session first.
    final ctx = EPmsContextProvider.of(context);
    if (ctx != null &&
        !await ReAuthGate.instance.require(ctx, SensitiveOp.endOfDay, context)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Run End of Day'),
        content: const Text(
          'This will process the End of Day for the current business date. '
          'This action cannot be undone. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Run EOD')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _running = true);
    try {
      await widget.client.runEod(
        propertyId: widget.propertyId,
      );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('End of Day processed successfully.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
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
          final data = snapshot.data!;
          final businessDate =
              data['business_date'] as String? ?? DateTime.now().toIso8601String();
          final steps = data['steps'] as List<dynamic>? ?? [];
          final exceptions = data['exceptions'] as List<dynamic>? ?? [];
          final ready = data['ready'] as bool? ?? true;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Steps panel ──
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End of Day Processing',
                          style: theme.textTheme.headlineSmall),
                      Text(
                          'Business Date: ${DateFormat.yMMMd().format(DateTime.tryParse(businessDate) ?? DateTime.now())}'),
                      const SizedBox(height: 16),
                      if (steps.isEmpty)
                        const Text('No EOD steps available.')
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: steps.length,
                            itemBuilder: (context, i) {
                              final step = steps[i] as Map<String, dynamic>;
                              final status = step['status'] as String? ?? 'pending';
                              final icon = <String, IconData>{
                                'pending': Icons.pending,
                                'in-progress': Icons.hourglass_top,
                                'completed': Icons.check_circle,
                                'failed': Icons.error,
                              }[status] ??
                                  Icons.pending;
                              final color = <String, Color>{
                                'pending': Colors.grey,
                                'in-progress': Colors.blue,
                                'completed': Colors.green,
                                'failed': Colors.red,
                              }[status] ??
                                  Colors.grey;
                              return ListTile(
                                leading: Icon(icon, color: color),
                                title: Text(step['name'] as String? ?? 'Step ${i + 1}'),
                                subtitle: Text(step['description'] as String? ?? status),
                                trailing: Text(status),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _running || !ready ? null : _runEod,
                        icon: _running
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.play_arrow),
                        label: const Text('Run End of Day'),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              // ── Exceptions panel ──
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Exceptions',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (exceptions.isEmpty)
                        Card(
                          color: Colors.green.shade50,
                          child: const ListTile(
                            leading: Icon(Icons.check_circle, color: Colors.green),
                            title: Text('No exceptions'),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: exceptions.length,
                            itemBuilder: (context, i) {
                              final exc = exceptions[i] as Map<String, dynamic>;
                              final severity =
                                  exc['severity'] as String? ?? 'warning';
                              final color = <String, Color>{
                                'info': Colors.blue,
                                'warning': Colors.amber,
                                'error': Colors.red,
                              }[severity] ??
                                  Colors.amber;
                              return Card(
                                child: ListTile(
                                  leading: Icon(Icons.warning, color: color),
                                  title: Text(exc['title'] as String? ?? 'Exception'),
                                  subtitle: Text(
                                      exc['description'] as String? ?? ''),
                                  trailing: Chip(label: Text(severity)),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}