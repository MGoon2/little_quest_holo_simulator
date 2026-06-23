import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_data.dart';

/// 카드 메타데이터 영구 저장.
///
/// SharedPreferences 에 JSON 배열로 저장한다.
/// 사진 파일 자체는 PhotoService 가 앱 디렉토리에 복사해두므로
/// 경로만 보존하면 된다.
class CardStore {
  static const _key = 'cards_v1';

  Future<List<CardData>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => CardData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAll(List<CardData> cards) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(cards.map((c) => c.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  Future<List<CardData>> add(CardData card) async {
    final cards = await loadAll();
    cards.add(card);
    await saveAll(cards);
    return cards;
  }

  Future<List<CardData>> update(CardData card) async {
    final cards = await loadAll();
    final i = cards.indexWhere((c) => c.id == card.id);
    if (i >= 0) cards[i] = card;
    await saveAll(cards);
    return cards;
  }

  Future<List<CardData>> remove(String id) async {
    final cards = await loadAll();
    cards.removeWhere((c) => c.id == id);
    await saveAll(cards);
    return cards;
  }
}
