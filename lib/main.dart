// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

// ePMS main entry point — bootstrap flow (epms/DESIGN.md §2):
//
// 1. App starts, calls GET /v1/app/runtime/context (routed through TLS)
// 2. TLS injects X-Sentin8-App-Id, X-Sentin8-Env-Id headers
// 3. Receives AppRuntimeContext { authDomain, bffDomain, org, env }
// 4. Initializes BffAuthProvider with BFF base URL
// 5. Checks BFF /auth/session for existing session
// 6. Renders signed-in dashboard or landing page with Sign In / Sign Up

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:sentin8/sentin8.dart';

import 'app_context.dart';
import 'app.dart';
import 'screens/screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable semantics for e2e/Playwright ARIA access.
  SemanticsBinding.instance.ensureSemantics();
  runApp(const EPmsApp());
}

/// ePMS root widget.
///
/// Shows a bootstrap loader while fetching runtime context, then the main app.
class EPmsApp extends StatefulWidget {
  const EPmsApp({super.key});

  @override
  State<EPmsApp> createState() => _EPmsAppState();
}

class _EPmsAppState extends State<EPmsApp> {
  AppRuntimeContext? _runtimeContext;
  EPmsContext? _pmsContext;
  String? _bootstrapError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Use same-origin (empty string) so the TLS proxy injects the
      // correct X-Sentin8-Hostname header for runtime context resolution.
      final ctx = await fetchRuntimeContext(appBaseUrl: '');
      // Create the EPmsContext (initializes auth provider, checks session).
      final pmsCtx = await EPmsContext.create(ctx);
      setState(() {
        _runtimeContext = ctx;
        _pmsContext = pmsCtx;
      });
    } catch (e) {
      setState(() {
        _bootstrapError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _runtimeContext?.displayName ?? 'ePMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_bootstrapError != null) {
      return BootstrapErrorPage(
        error: _bootstrapError!,
        appName: 'ePMS',
      );
    }

    if (_runtimeContext == null) {
      return const BootstrapLoaderPage(appName: 'ePMS');
    }

    if (_pmsContext == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return EPmsContextProvider(
      context: _pmsContext!,
      child: EPmsShell(),
    );
  }
}