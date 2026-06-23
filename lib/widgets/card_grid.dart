import 'package:flutter/material.dart';

import '../models/card_data.dart';
import 'holo_card.dart';

/// 카드 갤러리 그리드.
///
/// 현재는 단일 카드를 크게 보여주는 MVP 형태.
/// Phase 7 에서 다중 카드 관리로 확장한다.
class CardGrid extends StatelessWidget {
  const CardGrid({
    super.key,
    required this.cards,
    required this.onTapCard,
    required this.onLongPressCard,
  });

  final List<CardData> cards;
  final void Function(CardData) onTapCard;
  final void Function(CardData) onLongPressCard;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const _EmptyState();
    }
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        childAspectRatio: 2.5 / 3.5,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: cards.length,
      itemBuilder: (context, i) {
        final card = cards[i];
        return HoloCard(
          data: card,
          onTap: () => onTapCard(card),
          onLongPress: () => onLongPressCard(card),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined,
              size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            '아직 카드가 없습니다',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white54,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            '오른쪽 아래 + 버튼을 눌러\n직접 찍은 사진으로 카드를 만들어보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, height: 1.5),
          ),
        ],
      ),
    );
  }
}
