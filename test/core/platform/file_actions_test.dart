import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/core/platform/file_actions.dart';
import 'package:path/path.dart' as p;

/// Task 8.6: trash, rename and move from the library.
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('kyndrel_files'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File touch(String rel) => File(p.join(tmp.path, rel))
    ..createSync(recursive: true)
    ..writeAsStringSync(rel);

  test('Linux without gio: the freedesktop trash, restorable', () async {
    final film = touch('Films/Heist.mkv');
    final calls = <String>[];
    final actions = FileActions(
      os: 'linux',
      environment: {'HOME': tmp.path},
      run: (exe, args) async {
        calls.add(exe);
        throw ProcessException(exe, args);
      },
    );
    await actions.trash(film.path);
    expect(calls, ['gio']);
    expect(film.existsSync(), isFalse);
    final trash = p.join(tmp.path, '.local', 'share', 'Trash');
    expect(File(p.join(trash, 'files', 'Heist.mkv')).existsSync(), isTrue);
    final info = File(p.join(trash, 'info', 'Heist.mkv.trashinfo'))
        .readAsStringSync();
    expect(info, contains('Path=${Uri.file(film.path).path}'));
    expect(info, contains('DeletionDate='));

    // A second file of the same name doesn't overwrite the first.
    final again = touch('Other/Heist.mkv');
    await actions.trash(again.path);
    expect(File(p.join(trash, 'files', 'Heist.2.mkv')).existsSync(), isTrue);
  });

  test('gio trash is used when it works; failures throw', () async {
    final film = touch('a.mkv');
    final ok = FileActions(
      os: 'linux',
      run: (exe, args) async => ProcessResult(1, 0, '', ''),
    );
    await ok.trash(film.path);
    expect(film.existsSync(), isTrue, reason: 'gio moved it (faked)');
    final mac = FileActions(
      os: 'macos',
      run: (exe, args) async => ProcessResult(1, 1, '', 'denied'),
    );
    expect(() => mac.trash(film.path), throwsA(isA<FileSystemException>()));
    expect(
      () => FileActions(os: 'android').trash(film.path),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('rename takes its subtitle files along', () async {
    final film = touch('Films/Heist.mkv');
    touch('Films/Heist.srt');
    touch('Films/Heist.en.ass');
    touch('Films/Heist.nfo');
    final actions = FileActions(os: 'linux');
    final renamed = await actions.rename(film.path, 'The Heist (2021).mkv');
    expect(p.basename(renamed), 'The Heist (2021).mkv');
    final names = Directory(p.join(tmp.path, 'Films'))
        .listSync()
        .map((e) => p.basename(e.path))
        .toSet();
    expect(names, {
      'The Heist (2021).mkv',
      'The Heist (2021).srt',
      'The Heist (2021).en.ass',
      'Heist.nfo',
    });
    expect(
      () => actions.rename(renamed, 'bad/name.mkv'),
      throwsA(isA<FileSystemException>()),
    );
    touch('Films/Taken.mkv');
    expect(
      () => actions.rename(renamed, 'Taken.mkv'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('move takes its subtitle files along', () async {
    final film = touch('Films/Heist.mkv');
    touch('Films/Heist.srt');
    final dest = Directory(p.join(tmp.path, 'Watched'))..createSync();
    final moved = await FileActions(os: 'linux').move(film.path, dest.path);
    expect(moved, p.join(dest.path, 'Heist.mkv'));
    expect(File(p.join(dest.path, 'Heist.srt')).existsSync(), isTrue);
    expect(film.existsSync(), isFalse);
  });
}
