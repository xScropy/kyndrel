import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/resume_repository.dart';

void main() {
  late KyndrelDatabase db;
  late ResumeRepository repo;

  setUp(() {
    db = KyndrelDatabase(NativeDatabase.memory());
    repo = ResumeRepository(db);
  });

  tearDown(() => db.close());

  const hour = Duration(hours: 1);

  test('saves and reads a position', () async {
    await repo.save('/a.mkv', const Duration(minutes: 12), hour);
    final p = await repo.get('/a.mkv');
    expect(p?.position, const Duration(minutes: 12));
    expect(p?.duration, hour);
  });

  test('updates in place', () async {
    await repo.save('/a.mkv', const Duration(minutes: 1), hour);
    await repo.save('/a.mkv', const Duration(minutes: 2), hour);
    expect((await repo.get('/a.mkv'))?.position, const Duration(minutes: 2));
  });

  test('barely started or finished files are forgotten', () async {
    await repo.save('/a.mkv', const Duration(minutes: 10), hour);
    await repo.save('/a.mkv', const Duration(seconds: 3), hour);
    expect(await repo.get('/a.mkv'), isNull);

    await repo.save('/b.mkv', const Duration(minutes: 10), hour);
    await repo.save('/b.mkv', const Duration(minutes: 59, seconds: 50), hour);
    expect(await repo.get('/b.mkv'), isNull);
  });

  test('isResumable', () {
    expect(
      ResumeRepository.isResumable(const Duration(seconds: 5), hour),
      isFalse,
    );
    expect(
      ResumeRepository.isResumable(const Duration(minutes: 30), hour),
      isTrue,
    );
    expect(
      ResumeRepository.isResumable(const Duration(minutes: 58), hour),
      isFalse,
    );
    expect(
      ResumeRepository.isResumable(const Duration(minutes: 5), Duration.zero),
      isTrue,
    );
  });
}
