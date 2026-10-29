// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

// ePMS app context - central runtime state (epms/DESIGN.md §2).
//
// Holds the AppRuntimeContext, BffAuthProvider, the resolved property id,
// and provides them to the widget tree via InheritedWidget.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:sentin8/sentin8.dart';

import 'bff_client.dart';

/// Central app context that ties together runtime context and auth.
class EPmsContext extends ChangeNotifier {
  final AppRuntimeContext runtimeContext;
  final BffAuthProvider auth;

  /// Properties visible to this environment (PMS property registry)  - 
  /// multi-property environments surface the picker in the shell
  /// (epms/DESIGN.md §10).
  final List<PropertySummary> properties;

  /// Property the console manages - the registry's first row by default;
  /// `selectProperty` re-resolves the console to another property. Falls
  /// back to the environment id when the registry is unreachable.
  String _propertyId;
  String get propertyId => _propertyId;

  late final PmsBffClient client;

  EPmsContext._({
    required this.runtimeContext,
    required this.auth,
    required String initialPropertyId,
    required this.properties,
  }) : _propertyId = initialPropertyId {
    client = PmsBffClient(bffBaseUrl: runtimeContext.bffBaseUrl);
    auth.addListener(_onAuthChanged);
  }

  /// Re-bind the console to another property in place (the shell calls this
  /// from the switcher; listeners re-render against the new propertyId).
  void selectProperty(PropertySummary property) {
    if (property.id == propertyId) return;
    _propertyId = property.id;
    notifyListeners();
  }

  /// Re-bind the console to another property (multi-property envs).
  EPmsContext withProperty(PropertySummary property) => EPmsContext._(
        runtimeContext: runtimeContext,
        auth: auth,
        initialPropertyId: property.id,
        properties: properties,
      );

  /// Create the app context after bootstrap: auth init + property read.
  static Future<EPmsContext> create(AppRuntimeContext runtimeContext) async {
    // runtimeContext.authDomain already resolves the staff-auth fallback
    // (auth_domain → sentin8_auth_domain) inside the SDK; no separate
    // staffAuthDomain getter exists on AppRuntimeContext.
    final auth = BffAuthProvider(
      bffBaseUrl: runtimeContext.bffBaseUrl,
      authDomain: runtimeContext.authDomain,
      logPrefix: 'ePMS',
    );
    // Wire up redirect callback for web (window.location.href).
    // BffAuthProvider._redirect calls onRedirect - if unset, signInWithAuth()
    // and signUpWithAuth() silently do nothing.
    auth.onRedirect = (String url) {
      web.window.location.href = url;
    };
    await auth.init();
    // Property registry read - environments can host multiple properties;
    // the shell picks the first and offers the picker (epms/DESIGN.md §10).
    var propertyId = runtimeContext.environmentId;
    var properties = const <PropertySummary>[];
    try {
      final client = PmsBffClient(bffBaseUrl: runtimeContext.bffBaseUrl);
      final data = await client.getRawJson('/v1/properties');
      final items = (data['items'] as List<dynamic>?) ?? const [];
      properties = items
          .map((e) => PropertySummary.fromJson(e as Map<String, dynamic>))
          .toList();
      if (properties.isNotEmpty) {
        propertyId = properties.first.id;
      }
      client.close();
    } catch (_) {
      // Registry read is advisory - the env id remains the tenant context.
    }
    return EPmsContext._(
      runtimeContext: runtimeContext,
      auth: auth,
      initialPropertyId: propertyId,
      properties: properties,
    );
  }

  void _onAuthChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    auth.removeListener(_onAuthChanged);
    auth.dispose();
    super.dispose();
  }
}

/// InheritedWidget that provides the EPmsContext to the widget tree.
class EPmsContextProvider extends InheritedWidget {
  final EPmsContext context;

  const EPmsContextProvider({
    super.key,
    required this.context,
    required super.child,
  });

  static EPmsContext? of(BuildContext buildContext) {
    final provider = buildContext
        .dependOnInheritedWidgetOfExactType<EPmsContextProvider>();
    return provider?.context;
  }

  @override
  bool updateShouldNotify(EPmsContextProvider oldWidget) =>
      context != oldWidget.context;
}

/// Light property row for the picker (registry read projection).
class PropertySummary {
  final String id;
  final String propertyCode;
  final String propertyName;

  const PropertySummary({
    required this.id,
    required this.propertyCode,
    required this.propertyName,
  });

  factory PropertySummary.fromJson(Map<String, dynamic> json) =>
      PropertySummary(
        id: json['id'] as String,
        propertyCode: json['property_code'] as String? ?? '',
        propertyName: json['property_name'] as String? ?? '',
      );
}
