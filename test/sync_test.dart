import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:osis_jurnal/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('SyncAction serialization and deserialization', () {
    final action = SyncAction(
      id: 'test-123',
      actionType: SyncActionType.insert,
      table: 'siswa',
      data: {'id': 's1', 'nama': 'Budi', 'kelas': 'X RPL', 'nis': '12345'},
      targetId: 's1',
      createdAt: DateTime(2026, 8, 27, 10, 0, 0),
    );

    final json = action.toJson();
    final restored = SyncAction.fromJson(json);

    expect(restored.id, 'test-123');
    expect(restored.actionType, SyncActionType.insert);
    expect(restored.table, 'siswa');
    expect(restored.data?['nama'], 'Budi');
    expect(restored.targetId, 's1');
  });

  test('SyncService queue and clearQueue', () async {
    await SyncService.init();

    expect(SyncService.pendingCountNotifier.value, 0);

    await SyncService.enqueueAction(
      actionType: SyncActionType.insert,
      table: 'pelanggaran',
      data: {'id': 'p1', 'keterangan': 'Tidak pakai dasi'},
      targetId: 'p1',
    );

    final queue = await SyncService.getQueue();
    expect(queue.length, 1);
    expect(queue.first.table, 'pelanggaran');
    expect(SyncService.pendingCountNotifier.value, 1);

    await SyncService.clearQueue();
    final clearedQueue = await SyncService.getQueue();
    expect(clearedQueue.isEmpty, isTrue);
    expect(SyncService.pendingCountNotifier.value, 0);
  });
}
