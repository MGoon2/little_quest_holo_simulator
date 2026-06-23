import 'package:croppy/croppy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/card_data.dart';
import 'services/card_store.dart';
import 'widgets/card_editor_dialog.dart';
import 'widgets/card_grid.dart';

void main() {
  runApp(const HoloCardApp());
}

class HoloCardApp extends StatelessWidget {
  const HoloCardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Holo Card Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFA855F7),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: [
        CroppyLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ko'),
      ],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _store = CardStore();
  List<CardData> _cards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await _store.loadAll();
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _loading = false;
    });
  }

  Future<void> _openEditor([CardData? initial]) async {
    final result = await showDialog<CardData>(
      context: context,
      builder: (_) => CardEditorDialog(initial: initial),
    );
    if (result == null) return;
    final cards = initial == null
        ? await _store.add(result)
        : await _store.update(result);
    setState(() => _cards = cards);
  }

  Future<void> _deleteCard(CardData card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('카드 삭제'),
        content: Text('"${card.title}" 카드를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final cards = await _store.remove(card.id);
    setState(() => _cards = cards);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Holo Card Studio'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '정보',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAbout(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CardGrid(
              cards: _cards,
              onTapCard: (c) => _openEditor(c),
              onLongPressCard: _deleteCard,
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('카드 만들기'),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Holo Card Studio'),
        content: const Text(
          '직접 촬영한 사진을 홀로그래픽 트레이딩 카드로 만드는 앱.\n\n'
          '홀로그래픽 효과 기법은 simeydotme/pokemon-cards-css 및 '
          'pokemon-cards-151 프로젝트의 아이디어를 참고하여 '
          'Flutter 로 독자적으로 구현했습니다. 카드 프레임과 이미지 자산은 '
          '오리지널 디자인이며 포켓몬 TCG 의 자산을 사용하지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
