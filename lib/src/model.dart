import 'dart:typed_data';

class AnkiNote {
  final int id;
  final String guid;
  final int mid;
  final List<String> flds;
  final String deckId;
  final String deckName;

  AnkiNote({required this.id, required this.guid, required this.mid, required this.flds, required this.deckId, required this.deckName});

  factory AnkiNote.fromMap(Map<String, dynamic> map) {
    return AnkiNote(
      id: map['id'] as int,
      guid: map['guid'] as String,
      mid: map['mid'] as int,
      flds: (map['flds'] as String).split('\x1f'),
      deckId: map['deck_id'] as String,
      deckName: map['deck_name'] as String,
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
    };
  }
} 