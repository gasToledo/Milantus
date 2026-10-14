import 'package:dnd_server/src/repositories/level_up_repository.dart';
import 'package:test/test.dart';

import 'fakes/recording_session.dart';

void main() {
  // El cliente ya está escrito contra esta forma: el id viaja como texto
  // aunque la columna sea una secuencia, y un capítulo nulo no se manda.
  test('lee las columnas con el contrato del cuaderno', () async {
    final session = RecordingSession()
      ..nextRows = [
        {
          'id': 123,
          'chapter_id': null,
          'character_name': 'Arwen',
          'level': 5,
          'class_id': 'rogue',
          'class_level': 3,
          'created_at': DateTime.utc(2026, 10, 14, 12),
        },
      ];

    final logs = await PostgresLevelUpRepository(
      session,
    ).listFor('00000000-0000-0000-0000-000000000001', 'tumba');

    expect(logs.single.toJson(), {
      'id': '123',
      'characterName': 'Arwen',
      'level': 5,
      'classId': 'rogue',
      'classLevel': 3,
      'at': '2026-10-14T12:00:00.000Z',
    });
    expect(session.executedParameters.single, contains('dmUserId'));
  });
}
