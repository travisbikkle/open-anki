import 'dart:typed_data';

class AnkiNote {
  final int id;
  final String guid;
  final int mid;
  final List<String> flds;
  final String deckId;
  final String deckName;
  final String? notetypeName; // 新增模板名字段

  AnkiNote({required this.id, required this.guid, required this.mid, required this.flds, required this.deckId, required this.deckName, this.notetypeName});

  factory AnkiNote.fromMap(Map<String, dynamic> map) {
    return AnkiNote(
      id: map['id'] as int,
      guid: map['guid'] as String,
      mid: map['mid'] as int,
      flds: (map['flds'] as String).split('\x1f'),
      deckId: map['deck_id'] as String,
      deckName: map['deck_name'] as String,
      notetypeName: map['notetype_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'guid': guid,
      'mid': mid,
      'flds': flds.join('\x1f'),
      'deck_id': deckId,
      'deck_name': deckName,
      if (notetypeName != null) 'notetype_name': notetypeName,
    };
  }
} 