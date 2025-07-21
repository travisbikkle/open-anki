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

class DeckInfo {
  final String deckId;
  final String deckName;
  final int cardCount;
  final int? lastReviewed;
  final int currentIndex;
  final String? version;
  
  DeckInfo({
    required this.deckId, 
    required this.deckName, 
    required this.cardCount, 
    this.lastReviewed, 
    this.currentIndex = 0,
    this.version,
  });

  factory DeckInfo.fromMap(Map<String, dynamic> map) {
    return DeckInfo(
      deckId: map['md5'] as String,
      deckName: (map['user_deck_name'] ?? '未命名题库') as String,
      cardCount: map['card_count'] as int? ?? 0,
      lastReviewed: map['last_reviewed'] as int?,
      currentIndex: map['current_index'] as int? ?? 0,
      version: map['version'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deckId': deckId,
      'deckName': deckName,
      'cardCount': cardCount,
      'lastReviewed': lastReviewed,
      'currentIndex': currentIndex,
      'version': version,
    };
  }
} 

class CardScheduling {
  final int cardId;
  final double stability;
  final double difficulty;
  final int due; // 时间戳（秒）

  CardScheduling({
    required this.cardId,
    required this.stability,
    required this.difficulty,
    required this.due,
  });

  factory CardScheduling.fromMap(Map<String, dynamic> map) {
    return CardScheduling(
      cardId: map['card_id'] as int,
      stability: map['stability'] as double,
      difficulty: map['difficulty'] as double,
      due: map['due'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'card_id': cardId,
      'stability': stability,
      'difficulty': difficulty,
      'due': due,
    };
  }
} 

// 学习模式
enum StudyMode {
  learn,    // 学习新卡片（按顺序）
  review,   // 复习到期卡片（按算法）
  preview,  // 自由预览（按顺序）
  custom    // 自定义复习
}

// 卡片状态
enum CardState {
  newCard,   // 新卡片
  learning,  // 正在学习
  review,    // 复习阶段
  done       // 已完成
}

// 学习计划设置
class StudyPlanSettings {
  final int newCardsPerDay;    // 每天新卡片数量限制
  final int reviewsPerDay;     // 每天复习数量限制
  final bool enableTimeLimit;  // 是否启用时间限制
  final int studyTimeMinutes;  // 学习时间限制（分钟）
  final StudyMode defaultMode; // 默认学习模式

  const StudyPlanSettings({
    this.newCardsPerDay = 20,
    this.reviewsPerDay = 100,
    this.enableTimeLimit = false,
    this.studyTimeMinutes = 30,
    this.defaultMode = StudyMode.review,
  });

  // 从Map创建
  factory StudyPlanSettings.fromMap(Map<String, dynamic> map) {
    return StudyPlanSettings(
      newCardsPerDay: map['newCardsPerDay'] ?? 20,
      reviewsPerDay: map['reviewsPerDay'] ?? 99,
      enableTimeLimit: map['enableTimeLimit'] ?? false,
      studyTimeMinutes: map['studyTimeMinutes'] ?? 30,
      defaultMode: StudyMode.values[map['defaultMode'] ?? StudyMode.review.index],
    );
  }

  // 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'newCardsPerDay': newCardsPerDay,
      'reviewsPerDay': reviewsPerDay,
      'enableTimeLimit': enableTimeLimit,
      'studyTimeMinutes': studyTimeMinutes,
      'defaultMode': defaultMode.index,
    };
  }

  // 创建一个修改后的副本
  StudyPlanSettings copyWith({
    int? newCardsPerDay,
    int? reviewsPerDay,
    bool? enableTimeLimit,
    int? studyTimeMinutes,
    StudyMode? defaultMode,
  }) {
    return StudyPlanSettings(
      newCardsPerDay: newCardsPerDay ?? this.newCardsPerDay,
      reviewsPerDay: reviewsPerDay ?? this.reviewsPerDay,
      enableTimeLimit: enableTimeLimit ?? this.enableTimeLimit,
      studyTimeMinutes: studyTimeMinutes ?? this.studyTimeMinutes,
      defaultMode: defaultMode ?? this.defaultMode,
    );
  }
}

// 每日学习统计
class DailyStudyStats {
  final String deckId;
  final DateTime date;
  final int newCardsLearned;
  final int cardsReviewed;
  final int totalTime;       // 总学习时间（秒）
  final int correctCount;    // 正确数量
  final int totalCount;      // 总卡片数量

  const DailyStudyStats({
    required this.deckId,
    required this.date,
    required this.newCardsLearned,
    required this.cardsReviewed,
    required this.totalTime,
    required this.correctCount,
    required this.totalCount,
  });

  // 从Map创建
  factory DailyStudyStats.fromMap(Map<String, dynamic> map) {
    return DailyStudyStats(
      deckId: map['deckId'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      newCardsLearned: map['newCardsLearned'] as int,
      cardsReviewed: map['cardsReviewed'] as int,
      totalTime: map['totalTime'] as int,
      correctCount: map['correctCount'] as int,
      totalCount: map['totalCount'] as int,
    );
  }

  // 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'deckId': deckId,
      'date': date.millisecondsSinceEpoch,
      'newCardsLearned': newCardsLearned,
      'cardsReviewed': cardsReviewed,
      'totalTime': totalTime,
      'correctCount': correctCount,
      'totalCount': totalCount,
    };
  }
} 