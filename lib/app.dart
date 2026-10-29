// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

// ePMS app shell - auth-aware navigation.
//
// When not signed in: shows a landing page with Sign In button.
// When signed in: shows the PMS dashboard with NavigationRail.

import 'package:flutter/material.dart';

import 'app_context.dart';
import 'rfw/ops_page.dart';
import 'screens/screens.dart';

/// Auth-aware shell. Shows landing page or PMS dashboard.
class EPmsShell extends StatefulWidget {
  const EPmsShell({super.key});

  @override
  State<EPmsShell> createState() => _EPmsShellState();
}

class _EPmsShellState extends State<EPmsShell> {
  @override
  Widget build(BuildContext context) {
    final ctx = EPmsContextProvider.of(context);
    if (ctx == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final auth = ctx.auth;
    if (!auth.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!auth.isSignedIn) {
      return _LandingPage(ctx: ctx);
    }

    return const EPmsDashboard();
  }
}

/// Landing page shown when the user is not signed in.
/// Has "Sign In" and "Sign Up" buttons that redirect to Auth via BFF.
class _LandingPage extends StatelessWidget {
  final EPmsContext ctx;
  const _LandingPage({required this.ctx});

  @override
  Widget build(BuildContext context) {
    final rc = ctx.runtimeContext;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hotel, size: 64, color: Colors.blueGrey[300]),
            const SizedBox(height: 16),
            Text(
              rc.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to manage your property',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => ctx.auth.signInWithAuth(),
              icon: const Icon(Icons.login),
              label: const Text('Sign In'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ctx.auth.signUpWithAuth(),
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}

/// PMS dashboard with NavigationRail - shown when signed in.
class EPmsDashboard extends StatefulWidget {
  const EPmsDashboard({super.key});

  @override
  State<EPmsDashboard> createState() => _EPmsDashboardState();
}

class _EPmsDashboardState extends State<EPmsDashboard> {
  int _index = 0;

  static const _destinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Dashboard'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: Text('Reservations'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.bedroom_parent_outlined),
      selectedIcon: Icon(Icons.bedroom_parent),
      label: Text('Front Desk'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: Text('Cashiering'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.attach_money_outlined),
      selectedIcon: Icon(Icons.attach_money),
      label: Text('Rates'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.event_outlined),
      selectedIcon: Icon(Icons.event),
      label: Text('Blocks'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: Text('Profiles'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.assessment_outlined),
      selectedIcon: Icon(Icons.assessment),
      label: Text('Reports'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.widgets_outlined),
      selectedIcon: Icon(Icons.widgets),
      label: Text('RFW Ops'),
    ),
  ];

  String get _title {
    const titles = [
      'Dashboard', 'Reservations', 'Front Desk', 'Cashiering',
      'Rate Plans', 'Blocks', 'Profiles', 'Reports', 'RFW Ops',
    ];
    return titles[_index];
  }

  @override
  Widget build(BuildContext context) {
    final ctx = EPmsContextProvider.of(context)!;
    final auth = ctx.auth;
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: Text('PMS - $_title'),
        actions: [
          // Multi-property switcher (epms/DESIGN.md §10): environments hosting
          // several properties re-bind the console from the app-bar menu.
          if (ctx.properties.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.apartment),
              tooltip: 'Switch property',
              onSelected: (propertyId) {
                final p = ctx.properties.firstWhere((p) => p.id == propertyId);
                ctx.selectProperty(p);
              },
              itemBuilder: (_) => [
                for (final p in ctx.properties)
                  PopupMenuItem(
                    value: p.id,
                    child: Text(p.propertyName),
                  ),
              ],
            ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(user.email, style: const TextStyle(fontSize: 14)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            extended: MediaQuery.of(context).size.width > 1200,
            destinations: _destinations,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _pageFor(_index, ctx),
          ),
        ],
      ),
    );
  }

  Widget _pageFor(int index, EPmsContext ctx) {
    final client = ctx.client;
    // Property resolved from the registry at bootstrap (app_context.dart);
    // falls back to the environment id when the registry is unreachable.
    final propertyId = ctx.propertyId;
    switch (index) {
      case 0:
        return DashboardPage(client: client, propertyId: propertyId);
      case 1:
        return ReservationSearchPage(client: client, propertyId: propertyId);
      case 2:
        return RoomStatusGridPage(client: client, propertyId: propertyId);
      case 3:
        return FolioSearchPage(client: client, propertyId: propertyId);
      case 4:
        return RatePlansPage(client: client, propertyId: propertyId);
      case 5:
        return BlocksPage(client: client, propertyId: propertyId);
      case 6:
        return ProfilesPage(client: client, propertyId: propertyId);
      case 7:
        return EodDashboardPage(client: client, propertyId: propertyId);
      case 8:
        // RFW-hosted operations page - the same UI definitions the
        // Sentin8:Dash admin renders, hosted in-app via the shared renderer
        // (epms/DESIGN.md §2, RFW page host).
        return EPmsRfwPage(
          page: _rfwPageFor(_rfwIndex),
          bffClient: client,
          onNavigate: (route) => setState(() => _rfwIndex = route),
        );
      default:
        return DashboardPage(client: client, propertyId: propertyId);
    }
  }

  String _rfwIndex = 'overview';

  String _rfwPageFor(String route) {
    // Route shape: "/{page}" or "{page}" - strip any leading slash.
    return route.startsWith('/') ? route.substring(1) : route;
  }
}