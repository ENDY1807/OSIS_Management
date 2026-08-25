import 'package:flutter_test/flutter_test.dart';
import 'package:osis_jurnal/services/auth_service.dart';

void main() {
  test('normalizeUsername handles casing and spaces', () {
    expect(AuthService.normalizeUsername('sekbid 10'), 'SEKBID10');
    expect(AuthService.normalizeUsername('pembina'), 'PEMBINA');
    expect(AuthService.normalizeUsername('  ketua  '), 'KETUA');
    expect(AuthService.normalizeUsername('SEKBID 1'), 'SEKBID1');
  });

  test('sekbidList contains all 10 sekbid', () {
    expect(AuthService.sekbidList.length, 10);
    expect(AuthService.sekbidList.contains('SEKBID10'), isTrue);
  });

  test('checkPassword matches default passwords with normalization', () {
    expect(AuthService.checkPassword('ketua', 'OSISBN666'), isTrue);
    expect(AuthService.checkPassword('sekbid 10', 'KomunikasiBahasa'), isTrue);
    expect(AuthService.checkPassword('pembina', 'PembinaOSIS'), isTrue);
    expect(AuthService.checkPassword('ketua', 'wrongpass'), isFalse);
  });
}
