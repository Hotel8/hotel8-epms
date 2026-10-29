// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

// rfw/widget_hosts.dart
//
// Custom RFW widget hosts for the ePMS staff app `epms/DESIGN.md` §4.
//
// The shared SDK's RFW renderer calls `actions.renderNativeWidget(widgetName,
// props, dataEndpoint)` for `Native` widgets - this registry is the ePMS
// host map for hospitality widgets RFW cannot express generically (date
// pickers, occupancy gauge, room-status grid, folio viewer, …).
//
// Each host reads its configuration from RFW `props` and writes user input
// back through the provided `onValueChanged` callback (form binding contract).

import 'package:flutter/material.dart';

/// Signature of a native widget host factory. Receives the ambient
/// [BuildContext] so hosts can show pickers/dialogs.
typedef RfwWidgetHost = Widget Function(
  BuildContext context,
  Map<String, dynamic> props,
  String? dataEndpoint,
  ValueChanged<Object?> onValueChanged,
);

/// Registry of ePMS widget hosts, keyed by the RFW `widget_name`.
///
/// Passed into `RfwActions.renderNativeWidget` by the RFW page host.
final Map<String, RfwWidgetHost> epmsWidgetHosts = {
  'DatePicker': _datePicker,
  'DateRangePicker': _dateRangePicker,
  'TimePicker': _timePicker,
  'DateTimePicker': _dateTimePicker,
  'OccupancyGauge': _occupancyGauge,
  'RoomStatusGrid': _roomStatusGrid,
  'FolioViewer': _folioViewer,
  'RoomAssignmentPicker': _roomAssignmentPicker,
  'BlockStatusTracker': _blockStatusTracker,
  'CalendarView': _calendarView,
};

String _str(Map<String, dynamic> props, String key, [String fallback = '']) =>
    (props[key] as String?) ?? fallback;

// ── DatePicker ─────────────────────────────────────────────────────

Widget _datePicker(
  BuildContext context,
  Map<String, dynamic> props,
  String? dataEndpoint,
  ValueChanged<Object?> onValueChanged,
) {
  return _PickerField(
    label: _str(props, 'label', 'Pick a date'),
    initialText: _str(props, 'initialValue'),
    icon: Icons.calendar_today,
    onTap: () async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(_str(props, 'initialValue')) ?? now,
        firstDate: DateTime.tryParse(_str(props, 'firstDate')) ?? now,
        lastDate:
            DateTime.tryParse(_str(props, 'lastDate')) ?? now.add(const Duration(days: 730)),
      );
      if (picked != null) {
        onValueChanged(picked.toIso8601String().substring(0, 10));
      }
    },
  );
}

// ── DateRangePicker ────────────────────────────────────────────────

Widget _dateRangePicker(
  BuildContext context,
  Map<String, dynamic> props,
  String? dataEndpoint,
  ValueChanged<Object?> onValueChanged,
) {
  return _PickerField(
    label: _str(props, 'label', 'Pick a date range'),
    initialText: _str(props, 'initialStartDate') == ''
        ? ''
        : '${_str(props, 'initialStartDate')}  -  ${_str(props, 'initialEndDate')}',
    icon: Icons.date_range,
    onTap: () async {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: now.subtract(const Duration(days: 365)),
        lastDate: now.add(const Duration(days: 730)),
      );
      if (range != null) {
        onValueChanged({
          'start': range.start.toIso8601String().substring(0, 10),
          'end': range.end.toIso8601String().substring(0, 10),
        });
      }
    },
  );
}

// ── TimePicker ─────────────────────────────────────────────────────

Widget _timePicker(
  BuildContext context,
  Map<String, dynamic> props,
  String? dataEndpoint,
  ValueChanged<Object?> onValueChanged,
) {
  return _PickerField(
    label: _str(props, 'label', 'Pick a time'),
    initialText: _str(props, 'initialValue'),
    icon: Icons.schedule,
    onTap: () async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked != null && context.mounted) {
        onValueChanged(picked.format(context));
      }
    },
  );
}

// ── DateTimePicker ─────────────────────────────────────────────────

Widget _dateTimePicker(
  BuildContext context,
  Map<String, dynamic> props,
  String? dataEndpoint,
  ValueChanged<Object?> onValueChanged,
) {
  return _PickerField(
    label: _str(props, 'label', 'Pick date & time'),
    initialText: _str(props, 'initialValue'),
    icon: Icons.event,
    onTap: () async {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: now.add(const Duration(days: 730)),
      );
      if (date == null) return;
      if (!context.mounted) return;
      final time =
          await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        final dt =
            DateTime(date.year, date.month, date.day, time.hour, time.minute);
        onValueChanged(dt.toIso8601String());
      }
    },
  );
}

// ── OccupancyGauge ─────────────────────────────────────────────────

Widget _occupancyGauge(
  BuildContext context,
  Map<String, dynamic> props,
  String? dataEndpoint,
  ValueChanged<Object?> onValueChanged,
) {
  final pct = ((props['value'] as num?) ?? 0).toDouble().clamp(0.0, 100.0);
  final label = _str(props, 'label', 'Occupancy');
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: pct / 100,
                  strokeWidth: 10,
                  semanticsLabel: 'Occupancy $pct%',
                ),
              ),
              Text('${pct.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.headlineSmall),
            ]),
          ),
        ],
      ),
    ),
  );
}

// ── RoomStatusGrid ─────────────────────────────────────────────────

Widget _roomStatusGrid(
  BuildContext context,
  Map<String, dynamic> props,
  String? dataEndpoint,
  ValueChanged<Object?> onValueChanged,
) {
  final rooms = (props['rooms'] as List?) ?? const [];
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: rooms.map((r) {
      final room = r as Map<String, dynamic>;
      final status = (room['status'] as String? ?? 'CLEAN').toUpperCase();
      final color = switch (status) {
        'CLEAN' || 'INSPECTED' => Colors.green.shade400,
        'DIRTY' || 'PICKUP' => Colors.orange.shade400,
        'OUT_OF_ORDER' || 'OUT_OF_SERVICE' => Colors.red.shade400,
        _ => Colors.blueGrey.shade300,
      };
      return Tooltip(
        message: status,
        child: Chip(
          backgroundColor: color.withValues(alpha: 0.25),
          label: Text('${room['room_number'] ?? room['roomNumber'] ?? '?'}'),
        ),
      );
    }).toList(),
  );
}

// ── FolioViewer ────────────────────────────────────────────────────

Widget _folioViewer(
  BuildContext context,
  Map<String, dynamic> props,
  String? dataEndpoint,
  ValueChanged<Object?> onValueChanged,
) {
  final lines = (props['lines'] as List?) ?? const [];
  final total = (props['total'] as num?) ?? 0;
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Folio', style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          ...lines.map((l) {
            final line = l as Map<String, dynamic>;
            return ListTile(
              dense: true,
              title: Text('${line['description'] ?? line['code'] ?? ''}'),
              trailing: Text('${line['amount'] ?? '0.00'}'),
            );
          }),
          const Divider(),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Total: $total',
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    ),
  );
}

// ── RoomAssignmentPicker ───────────────────────────────────────────

Widget _roomAssignmentPicker(
  BuildContext context,
  Map<String, dynamic> props,
  String? dataEndpoint,
  ValueChanged<Object?> onValueChanged,
) {
  final rooms = (props['rooms'] as List?) ?? const [];
  return DropdownButtonFormField<String>(
    decoration: InputDecoration(
      labelText: _str(props, 'label', 'Assign room'),
      border: const OutlineInputBorder(),
    ),
    initialValue: _str(props, 'initialValue').isEmpty
        ? null
        : _str(props, 'initialValue'),
    items: rooms
        .map((r) => DropdownMenuItem(
              value: r is Map ? '${r['room_number'] ?? r['roomNumber']}' : '$r',
              child: Text(r is Map ? '${r['room_number'] ?? r['roomNumber']}' : '$r'),
            ))
        .toList(),
    onChanged: (v) => onValueChanged(v),
  );
}

// ── BlockStatusTracker ─────────────────────────────────────────────

Widget _blockStatusTracker(
  BuildContext context,
  Map<String, dynamic> props,
  String? dataEndpoint,
  ValueChanged<Object?> onValueChanged,
) {
  final status = _str(props, 'status', 'PROVISIONAL').toUpperCase();
  const steps = ['PROVISIONAL', 'DEFINITIVE', 'RELEASED', 'CANCELLED'];
  final idx = steps.indexOf(status);
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < steps.length; i++)
            ListTile(
              dense: true,
              leading: Icon(
                i <= idx ? Icons.check_circle : Icons.radio_button_unchecked,
                color: i <= idx ? Colors.green : Colors.grey,
              ),
              title: Text(steps[i]),
            ),
        ],
      ),
    ),
  );
}

// ── CalendarView ──────────────────────────────────────────────────

Widget _calendarView(
  BuildContext context,
  Map<String, dynamic> props,
  String? dataEndpoint,
  ValueChanged<Object?> onValueChanged,
) {
  final initial = DateTime.tryParse(_str(props, 'initialValue')) ?? DateTime.now();
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: CalendarDatePicker(
        initialDate: initial,
        firstDate: initial.subtract(const Duration(days: 365)),
        lastDate: initial.add(const Duration(days: 730)),
        onDateChanged: (d) =>
            onValueChanged(d.toIso8601String().substring(0, 10)),
      ),
    ),
  );
}

// ── Shared picker field chrome ─────────────────────────────────────────────

class _PickerField extends StatelessWidget {
  final String label;
  final String initialText;
  final IconData icon;
  final Future<void> Function() onTap;

  const _PickerField({
    required this.label,
    required this.initialText,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        child: Text(initialText.isEmpty ? label : initialText),
      ),
    );
  }
}