import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model.dart';
import 'db.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

final currentIndexProvider = StateProvider<int>((ref) => 0);

final allDecksProvider = FutureProvider<List<DeckInfo>>((ref) async {
  return await AppDb.getAllDecks();
});

final recentDecksProvider = FutureProvider<List<DeckInfo>>((ref) async {
  return await AppDb.getRecentDecks(limit: 10);
});