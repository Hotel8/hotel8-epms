// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

// rfw/ops_page.dart
//
// ePMS RFW page host (epms/DESIGN.md §2) — fetches the service's RFW page
// definition (`GET /v1/admin/ui/{page}` through the BFF proxy), renders it
// with the shared SDK renderer, and registers the ePMS custom widget hosts
// (`rfw/widget_hosts.dart`) for `Native` widgets.
//
// The shared `Sentin8RfwPage` doesn't expose the `renderNativeWidget` hook,
// so this host wraps the renderer directly with the same caching + data/
// submit plumbing plus the hospitality widget registry.
//
// Caching policy: definitions cache in memory with a TTL (stale beyond a
// minute is refetched — the service may have rotated a page definition);
// the cache is per app process, keyed by page path. Access policy: RFW
// pages are fetched only when the session carries a scope the page needs —
// scope hints come from the session (`auth.scopes`); the service still
// authorizes every definition/data/submit request (client gating is UX).

import 'package:flutter/material.dart';

import 'package:sentin8/sentin8.dart';

import '../bff_client.dart';
import 'widget_hosts.dart';

/// ePMS RFW operations page host.
///
/// Fetches `GET {service}/v1/admin/ui/{page}` via the BFF client, caches the
/// definition (in-memory, cleared on navigation), and renders it. Native
/// widgets resolve through [epmsWidgetHosts].
class EPmsRfwPage extends StatefulWidget {
  /// RFW page path (e.g. `overview`, `reservations`).
  final String page;

  /// BFF client pointed at the hotel8-pms proxy.
  final PmsBffClient bffClient;

  /// Called when the RFW definition navigates to another page.
  final void Function(String route) onNavigate;

  const EPmsRfwPage({
    super.key,
    required this.page,
    required this.bffClient,
    required this.onNavigate,
  });

  @override
  State<EPmsRfwPage> createState() => _EPmsRfwPageState();
}

/// Process-wide RFW definition cache — TTL'd, keyed by page path
/// (`epms/DESIGN.md` §2 caching policy).
class RfwDefinitionCache {
  RfwDefinitionCache._();
  static final instance = RfwDefinitionCache._();

  static const _ttl = Duration(minutes: 1);

  final _entries = <String, _CacheEntry>{};

  AdminUiPage? get(String page) {
    final e = _entries[page];
    if (e == null) return null;
    if (DateTime.now().difference(e.fetchedAt) > _ttl) {
      _entries.remove(page);
      return null;
    }
    return e.page;
  }

  void put(String page, AdminUiPage def) =>
      _entries[page] = _CacheEntry(def, DateTime.now());

  void invalidate(String page) => _entries.remove(page);
}

class _CacheEntry {
  final AdminUiPage page;
  final DateTime fetchedAt;
  const _CacheEntry(this.page, this.fetchedAt);
}

/// Session scope gate — a page is fetched only when the session can
/// plausibly read it. PMS RFW pages live under `/v1/admin/ui/{page}` and the
/// service authorizes each request; this gate hides pages the session's
/// scopes cannot reach (UX: no doomed fetches).
bool rfwPageAllowed(AuthProviderStateLike auth, String page) {
  final scopes = auth.scopes;
  if (scopes.any((s) => s.contains('sys:admin'))) return true;
  // PMS staff scopes carry the vertical:service prefix.
  if (scopes.any((s) => s.startsWith('hotel8:pms:'))) return true;
  return false;
}

/// Minimal interface so the gate stays testable without the SDK type.
abstract class AuthProviderStateLike {
  List<String> get scopes;
}

class _AuthProviderStateLike implements AuthProviderStateLike {
  final BffAuthProvider auth;
  _AuthProviderStateLike(this.auth);

  @override
  List<String> get scopes => auth.scopes;
}

class _EPmsRfwPageState extends State<EPmsRfwPage> {
  AdminUiPage? _pageDef;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void didUpdateWidget(EPmsRfwPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cached = RfwDefinitionCache.instance.get(widget.page);
      if (cached != null) {
        setState(() {
          _pageDef = cached;
          _loading = false;
        });
        return;
      }
      final data =
          await widget.bffClient.getRawJson('/v1/admin/ui/${widget.page}');
      final response = AdminUiResponse.fromJson(data);
      if (response.responseType != 'page' || response.page == null) {
        setState(() {
          _error = response.errorMessage ?? 'RFW endpoint returned no page';
          _loading = false;
        });
        return;
      }
      RfwDefinitionCache.instance.put(widget.page, response.page!);
      setState(() {
        _pageDef = response.page;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _pageDef == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_error ?? 'Unknown error',
                style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _loadPage,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final page = _pageDef!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(page.title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: RfwRenderer(
              widgets: page.widgets,
              actions: RfwActions(
                onNavigate: widget.onNavigate,
                onRowClick: (_) {},
                fetchData: (endpoint) async {
                  final path = endpoint.startsWith('/v1/')
                      ? endpoint
                      : '/v1/admin$endpoint';
                  try {
                    final data = await widget.bffClient.getRawJson(path);
                    if (data['items'] is List) {
                      return (data['items'] as List).cast<Map<String, dynamic>>();
                    }
                    if (data['data'] is List) {
                      return (data['data'] as List).cast<Map<String, dynamic>>();
                    }
                    return [data];
                  } catch (_) {
                    return [];
                  }
                },
                submitForm: (endpoint, body) async {
                  final path = endpoint.startsWith('/')
                      ? endpoint
                      : '/v1/admin/$endpoint';
                  try {
                    final data = await widget.bffClient.postRawJson(path, body);
                    return AdminUiResponse.fromJson(data);
                  } catch (e) {
                    return AdminUiResponse.error(e.toString());
                  }
                },
                // Hospitality widget hosts — Native widgets resolve
                // through the ePMS registry (rfw/widget_hosts.dart).
                renderNativeWidget: (name, props, dataEndpoint) {
                  final host = epmsWidgetHosts[name];
                  if (host == null) return null;
                  return host(context, props, dataEndpoint, (_) {});
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}