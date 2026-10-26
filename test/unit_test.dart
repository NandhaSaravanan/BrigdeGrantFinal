import 'dart:convert';

import 'package:bridgegrant/src/config.dart';
import 'package:bridgegrant/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

String _jwt(Map<String, Object> payload) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(payload)}.signature';
}

void main() {
  group('AppConfig', () {
    test('reports missing values', () {
      expect(
        const AppConfig(supabaseUrl: '', supabaseKey: '').problem,
        isNotNull,
      );
    });

    test('accepts a publishable or anon key', () {
      expect(
        const AppConfig(
          supabaseUrl: 'https://abc.supabase.co',
          supabaseKey: 'sb_publishable_abc',
        ).problem,
        isNull,
      );
      expect(
        AppConfig(
          supabaseUrl: 'https://abc.supabase.co',
          supabaseKey: _jwt({'role': 'anon'}),
        ).problem,
        isNull,
      );
    });

    test('rejects service-role and secret keys', () {
      expect(looksLikeServiceRoleKey(_jwt({'role': 'service_role'})), isTrue);
      expect(looksLikeServiceRoleKey('sb_secret_abc'), isTrue);
      expect(looksLikeServiceRoleKey(_jwt({'role': 'anon'})), isFalse);
    });

    test('rejects an invalid URL', () {
      expect(
        const AppConfig(supabaseUrl: 'not a url', supabaseKey: 'k').problem,
        isNotNull,
      );
    });
  });

  test('sanitizeSearch strips PostgREST filter syntax', () {
    expect(sanitizeSearch('ymca),id.eq.(1'), 'ymca  id eq  1');
    expect(sanitizeSearch('  Winthrop  '), 'Winthrop');
  });

  test('GrantAggregate parses numeric strings and numbers', () {
    final row = GrantAggregate.fromJson({
      'city': 'Rock Hill',
      'grant_count': 208,
      'total_amount_usd': '12432794',
      'median_amount_usd': 15000.0,
    }, labelKey: 'city');
    expect(row.grantCount, 208);
    expect(row.totalAmountUsd, 12432794);
    expect(row.medianAmountUsd, 15000);
    expect(row.funderCount, isNull);
  });

  test('contact field validation', () {
    expect(isValidEmail('a@b.org'), isTrue);
    expect(isValidEmail('not-an-email'), isFalse);
    expect(isValidPhone('(803) 555-0100'), isTrue);
    expect(isValidPhone('+1 803 555 0100'), isTrue);
    expect(isValidPhone('12'), isFalse);
  });

  test('HelpRequest omits blank optional fields', () {
    const r = HelpRequest(
      fullName: ' Ann ',
      email: 'ann@x.org ',
      phone: '  ',
      helpTypes: ['other'],
    );
    expect(r.toJson(), {
      'full_name': 'Ann',
      'email': 'ann@x.org',
      'phone': null,
      'npo_name': null,
      'stage': null,
      'help_types': ['other'],
      'message': null,
      'consent': true,
    });
  });

  test('Grant treats a blank purpose as missing', () {
    final g = Grant.fromJson({
      'id': 'x',
      'amount_usd': 5,
      'tax_year': 2025,
      'purpose': '  ',
    });
    expect(g.purpose, isNull);
  });
}
