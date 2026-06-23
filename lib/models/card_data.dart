/// 카드 래리티 종류.
///
/// 원본 pokemon-cards-css / pokemon-cards-151 의 래리티 명칭을 차용하되,
/// 포켓몬 TCG 고유의 카드 레이아웃/이미지 자산은 사용하지 않는다.
/// 각 래리티는 홀로 효과의 종류/강도를 결정한다.
enum Rarity {
  basic, // 일반 카드 (홀로 없음, 글레어만)
  reverseHolo, // 역홀로 (전체 배경 포일)
  regularHolo, // 정규 홀로 (수직 빔)
  illustrationRare, // 일러스트 레어 (대각선 그래디언트)
  hyperRare, // 하이퍼 레어 (골드 에칭 + 글리터)
}

extension RarityX on Rarity {
  String get label {
    switch (this) {
      case Rarity.basic:
        return 'Basic';
      case Rarity.reverseHolo:
        return 'Reverse Holo';
      case Rarity.regularHolo:
        return 'Regular Holo';
      case Rarity.illustrationRare:
        return 'Illustration Rare';
      case Rarity.hyperRare:
        return 'Hyper Rare';
    }
  }

  /// 카드 프레임의 강조 색상 (오리지널 디자인).
  int get frameColor {
    switch (this) {
      case Rarity.basic:
        return 0xFF8A8A8A;
      case Rarity.reverseHolo:
        return 0xFF3B82F6;
      case Rarity.regularHolo:
        return 0xFFA855F7;
      case Rarity.illustrationRare:
        return 0xFFEC4899;
      case Rarity.hyperRare:
        return 0xFFEAB308;
    }
  }

  /// 홀로 효과를 적용할지 여부.
  bool get hasHolo => this != Rarity.basic;
}

/// 사용자가 만드는 단일 카드의 메타데이터.
///
/// 포켓몬 이름/번호/타입 대신 사용자가 직접 입력하는 범용 필드를 사용하여
/// 저작권 이슈를 회피한다. [imagePath] 는 사용자가 직접 촬영/선택한 사진의
/// 로컬 파일 경로이다.
class CardData {
  CardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.rarity,
    required this.imagePath,
    this.holoImagePath,
    this.memo = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final Rarity rarity;
  final String imagePath;
  /// 사용자가 직접 선택한 홀로 텍스처 이미지 경로.
  /// null 이면 래리티별 셰이더 홀로를 사용.
  final String? holoImagePath;
  final String memo;

  /// 사용자 홀로 이미지를 사용하는지 여부.
  bool get usesCustomHolo => holoImagePath != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'rarity': rarity.name,
        'imagePath': imagePath,
        if (holoImagePath != null) 'holoImagePath': holoImagePath,
        'memo': memo,
      };

  factory CardData.fromJson(Map<String, dynamic> json) => CardData(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        rarity: Rarity.values.byName(json['rarity'] as String),
        imagePath: json['imagePath'] as String,
        holoImagePath: json['holoImagePath'] as String?,
        memo: (json['memo'] as String?) ?? '',
      );

  CardData copyWith({
    String? title,
    String? subtitle,
    Rarity? rarity,
    String? imagePath,
    String? holoImagePath,
    bool clearHoloImage = false,
    String? memo,
  }) =>
      CardData(
        id: id,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        rarity: rarity ?? this.rarity,
        imagePath: imagePath ?? this.imagePath,
        holoImagePath:
            clearHoloImage ? null : (holoImagePath ?? this.holoImagePath),
        memo: memo ?? this.memo,
      );
}
