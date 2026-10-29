// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

/// Room Status Grid.
///
/// Color-coded grid of all rooms by floor. Each cell shows the room
/// number and is colored by its combined housekeeping + front-desk
/// status. Tapping a cell opens a dialog to update the room status.

import 'package:flutter/material.dart';

import '../bff_client.dart';
import '../models.dart';

class RoomStatusGridPage extends StatefulWidget {
  const RoomStatusGridPage({
    super.key,
    required this.client,
    required this.propertyId,
  });

  final PmsBffClient client;
  final String propertyId;

  @override
  State<RoomStatusGridPage> createState() => _RoomStatusGridPageState();
}

class _RoomStatusGridPageState extends State<RoomStatusGridPage> {
  late Future<List<RoomStatus>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.client
        .getRoomStatuses(propertyId: widget.propertyId)
        .then((items) => items.map((m) => RoomStatus.fromJson(m)).toList());
  }

  void _refresh() {
    setState(() {
      _future = widget.client
          .getRoomStatuses(propertyId: widget.propertyId)
          .then((items) => items.map((m) => RoomStatus.fromJson(m)).toList());
    });
  }

  Color _roomColor(RoomStatus r) {
    if (r.frontDeskStatus == 'out-of-order') return Colors.grey.shade700;
    if (r.frontDeskStatus == 'occupied') return Colors.red.shade300;
    if (r.frontDeskStatus == 'reserved') return Colors.blue.shade300;
    // Available - color by housekeeping
    switch (r.housekeepingStatus) {
      case 'clean':
        return Colors.green.shade300;
      case 'inspected':
        return Colors.teal.shade300;
      case 'dirty':
        return Colors.orange.shade300;
      case 'turndown':
        return Colors.purple.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  Future<void> _updateStatus(RoomStatus r) async {
    final statuses = ['clean', 'dirty', 'inspected', 'turndown', 'out-of-order'];
    final fdStatuses = ['available', 'occupied', 'reserved', 'out-of-order'];
    String? newHk = r.housekeepingStatus;
    String? newFd = r.frontDeskStatus;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Room ${r.roomNumber}'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: newHk,
                  decoration: const InputDecoration(labelText: 'Housekeeping'),
                  items: statuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => newHk = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: newFd,
                  decoration: const InputDecoration(labelText: 'Front Desk'),
                  items: fdStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => newFd = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
          ],
        ),
      ),
    );
    if (result != true || newHk == null) return;
    try {
      await widget.client.updateRoomStatus(
        propertyId: widget.propertyId,
        roomNumber: r.roomNumber,
        housekeepingStatus: newHk!,
        frontOfficeStatus: newFd,
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<RoomStatus>>(
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
          final rooms = snapshot.data!;
          // Group by floor
          final byFloor = <String, List<RoomStatus>>{};
          for (final r in rooms) {
            byFloor.putIfAbsent(r.floor, () => []).add(r);
          }
          final floors = byFloor.keys.toList()..sort();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Legend ──
              SizedBox(
                width: 180,
                child: Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Legend',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        _LegendItem('Available / Clean', Colors.green.shade300),
                        _LegendItem('Inspected', Colors.teal.shade300),
                        _LegendItem('Dirty', Colors.orange.shade300),
                        _LegendItem('Occupied', Colors.red.shade300),
                        _LegendItem('Reserved', Colors.blue.shade300),
                        _LegendItem('Turndown', Colors.purple.shade300),
                        _LegendItem('Out of Order', Colors.grey.shade700),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Grid ──
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: floors.length,
                  itemBuilder: (context, i) {
                    final floor = floors[i];
                    final floorRooms = byFloor[floor]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Floor $floor',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                            childAspectRatio: 1.6,
                          ),
                          itemCount: floorRooms.length,
                          itemBuilder: (context, j) {
                            final r = floorRooms[j];
                            return Tooltip(
                              message:
                                  'Room ${r.roomNumber}\n${r.frontDeskStatus} / ${r.housekeepingStatus}\n${r.guestName ?? ''}',
                              child: InkWell(
                                onTap: () => _updateStatus(r),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _roomColor(r),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: Colors.black.withOpacity(0.1)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(r.roomNumber,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      Text(r.frontDeskStatus,
                                          style: const TextStyle(fontSize: 9)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendItem(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}