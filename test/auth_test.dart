import 'package:flutter_test/flutter_test.dart';
import 'package:osis_jurnal/services/auth_service.dart';
import 'package:osis_jurnal/services/localization_service.dart';

void main() {
  test('normalizeUsername handles casing and spaces', () {
    expect(AuthService.normalizeUsername('sekbid 10'), 'SEKBID10');
    expect(AuthService.normalizeUsername('pembina'), 'PEMBINA');
    expect(AuthService.normalizeUsername('  ketua  '), 'KETUA');
    expect(AuthService.normalizeUsername('SEKBID 1'), 'SEKBID1');
    expect(AuthService.normalizeUsername(' admin '), 'ADMIN');
    expect(AuthService.normalizeUsername('kesiswaan'), 'KESISWAAN');
  });

  test('sekbidList contains all default sekbid', () {
    expect(AuthService.sekbidList.length >= 10, isTrue);
    expect(AuthService.sekbidList.any((s) => s.contains('10')), isTrue);
  });

  test('checkPassword matches default passwords with normalization', () {
    expect(AuthService.checkPassword('admin', 'EndyMahavira24!!@'), isTrue);
    expect(AuthService.checkPassword('kesiswaan', 'KesiswaanBaknus'), isTrue);
    expect(AuthService.checkPassword('bendahara', 'OSISBN666'), isTrue);
    expect(AuthService.checkPassword('sekbid 3', 'Bela Negara'), isTrue);
    expect(AuthService.checkPassword('sekbid 6', 'Kewirausahaan'), isTrue);
    expect(AuthService.checkPassword('sekbid 7', 'KebugaranJasmani'), isTrue);
    expect(AuthService.checkPassword('ketua', 'wrongpass'), isFalse);
  });

  test('getDisplayName returns correct names', () {
    expect(AuthService.getDisplayName('ADMIN'), 'Admin Aplikasi OSIS Management');
    expect(AuthService.getDisplayName('PEMBINA'), 'Pembina OSIS');
    expect(AuthService.getDisplayName('KESISWAAN'), 'Staf Kesiswaan');
    expect(AuthService.getDisplayName('ketua'), 'Ketua OSIS');
  });

  test('LocalizationService translations work', () {
    expect(LocalizationService.tr('app_title'), 'OSIS Management');
    expect(LocalizationService.tr('theme_dark'), 'Dark Mode');
  });
}
