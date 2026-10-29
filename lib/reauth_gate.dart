// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

// ePMS re-auth gate - sensitive operations (folio settlement, EOD) demand a
// fresh staff password confirmation before executing (epms/DESIGN.md §10,
// staff session policy default).
//
// Verification rides the same password check sign-in uses  - 
// `POST /proxy/auth/v1/sign-in` with the signed-in user's email (the BFF
// session proves who is asking; the password check proves the human is still
// present). Success renews the gate's freshness window (default 5 minutes)
// so a run of related operations doesn't re-prompt for every step.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_context.dart';

/// Time window after a successful re-auth during which further sensitive ops
/// skip the prompt.
const Duration sensitiveOpFreshness = Duration(minutes: 5);

/// Operations that require re-auth before execution.
enum SensitiveOp {
  folioSettle('Settle folio payment'),
  checkOut('Complete check-out'),
  endOfDay('Run end-of-day'),
  voidCharge('Void/adjust a posted charge');

  const SensitiveOp(this.label);
  final String label;
}

/// Re-auth freshness tracker (per app run; the BFF holds the session).
class ReAuthGate {
  ReAuthGate._();

  static final ReAuthGate instance = ReAuthGate._();

  DateTime? _lastReAuth;

  /// Whether a recent re-auth still covers the next sensitive op.
  bool get isFresh =>
      _lastReAuth != null &&
      DateTime.now().difference(_lastReAuth!) < sensitiveOpFreshness;

  void _renew() => _lastReAuth = DateTime.now();

  /// Gate the op: returns true when the op may proceed.
  Future<bool> require(EPmsContext ctx, SensitiveOp op, BuildContext context) async {
    if (isFresh) return true;
    final ok = await _prompt(ctx, op, context);
    if (ok) _renew();
    return ok;
  }

  Future<bool> _prompt(
      EPmsContext ctx, SensitiveOp op, BuildContext context) async {
    final passwordCtrl = TextEditingController();
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text('Confirm - ${op.label}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This operation settles money or closes the day.\n'
                  'Re-enter your password to continue.'),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                // Verify the staff credential through the BFF password
                // check (same endpoint the sign-in form uses).
                final email = ctx.auth.user?.email ?? '';
                final ok = await _verifyPassword(
                  ctx.runtimeContext.bffBaseUrl,
                  email: email,
                  password: passwordCtrl.text,
                );
                if (!dialogCtx.mounted) return;
                if (ok) {
                  Navigator.pop(dialogCtx, true);
                } else {
                  setDialogState(() =>
                      error = 'Password is incorrect for $email');
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }

  /// `POST /proxy/auth/v1/sign-in` - password verification for the active
  /// session's user (the session cookie identifies the account; this proves
  /// the human is present).
  static Future<bool> _verifyPassword(
    String bffBaseUrl,
    {required String email, required String password}
  ) async {
    try {
      final resp = await http.post(
        Uri.parse('$bffBaseUrl/proxy/auth/v1/sign-in'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}