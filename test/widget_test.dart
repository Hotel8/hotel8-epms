// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPMS
// SPDX-License-Identifier: Apache-2.0

// ePMS test suite.
//
// The full app (`lib/main.dart`) transitively imports the shared `sentin8`
// SDK, which is web-only (`package:web` in bootstrap/bff, `dart:html` in the
// RFW renderer) — it cannot compile on the VM test runner. App-shell smoke
// tests run via `flutter test --platform chrome` in the web pipeline.
//
// This suite exercises the SDK-free `PmsBffClient` — the transport the RFW
// page host (`rfw/ops_page.dart`) depends on — against an in-process HTTP
// server, covering the raw GET/POST plumbing end to end.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:epms/bff_client.dart';

void main() {
  late HttpServer server;
  late PmsBffClient client;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://127.0.0.1:${server.port}');
    client = PmsBffClient(bffBaseUrl: baseUri.toString());
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  test('getRawJson fetches an RFW page definition through the BFF', () async {
    // Serve a canned RFW page envelope (the shape `AdminUiResponse.fromJson`
    // expects from GET /v1/admin/ui/{page}).
    final page = {
      'response_type': 'page',
      'page': {
        'title': 'PMS Overview',
        'widgets': [
          {
            'type': 'Card',
            'props': {'title': 'Summary', 'children': []},
          },
        ],
        'actions': [],
      },
    };
    server.listen((req) async {
      if (req.uri.path == '/v1/admin/ui/overview') {
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode(page));
        await req.response.close();
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });

    final data = await client.getRawJson('/v1/admin/ui/overview');
    expect(data['response_type'], 'page');
    expect((data['page'] as Map)['title'], 'PMS Overview');
  });

  test('postRawJson submits a form and returns the response envelope',
      () async {
    Map<String, dynamic>? captured;
    server.listen((req) async {
      final body = await utf8.decoder.bind(req).join();
      captured = jsonDecode(body) as Map<String, dynamic>;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'response_type': 'redirect',
        'route': '/reservations',
      }));
      await req.response.close();
    });

    final resp = await client.postRawJson('/v1/admin/reservations', {
      'guest_profile_id': 'u-1',
      'arrival_date': '2026-09-10',
    });
    expect(captured?['guest_profile_id'], 'u-1');
    expect(resp['response_type'], 'redirect');
    expect(resp['route'], '/reservations');
  });

  test('postRawJson throws with the server message on error status', () async {
    server.listen((req) async {
      req.response.statusCode = HttpStatus.badRequest;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'message': 'arrival_date required'}));
      await req.response.close();
    });

    expect(
      () => client.postRawJson('/v1/admin/reservations', {}),
      throwsA(predicate((e) => '$e'.contains('arrival_date required'))),
    );
  });
}
