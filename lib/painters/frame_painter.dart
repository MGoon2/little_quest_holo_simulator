import 'package:flutter/material.dart';

import '../models/card_data.dart';

/// 오리지널 카드 프레임 디자인.
///
/// 포켓몬 TCG 의 레이아웃/이미지 자산을 사용하지 않고, 범용 트레이딩 카드
/// 스타일의 프레임을 CustomPaint 로 직접 그린다.
/// - 외곽 둥근 테두리 (래리티 색상)
/// - 상단 타이틀 바
/// - 하단 서브타이틀/래리티 라벨
/// - 사진 액자 영역은 [size] 기준 비율로 비워둔다 (이미지는 별도 레이어).
class FramePainter extends CustomPainter {
  FramePainter({
    required this.rarity,
    this.title = '',
    this.subtitle = '',
  });

  final Rarity rarity;
  final String title;
  final String subtitle;

  // 카드 비율 (포켓몬 카드와 동일한 2.5:3.5).
  static const double aspectRatio = 2.5 / 3.5;

  // 레이아웃 비율 (카드 높이 기준).
  static const double _borderFrac = 0.02;   // 외곽 테두리 두께 (얇게)
  static const double _titleBarFrac = 0.075; // 상단 타이틀 바 높이
  static const double _bottomBarFrac = 0.18; // 하단 정보 바 높이 (넓힘)

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final frameColor = Color(rarity.frameColor);

    // 외곽 테두리.
    final borderThickness = h * _borderFrac;
    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(h * 0.035),
    );
    final borderPaint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderThickness;
    canvas.drawRRect(rRect, borderPaint);

    // 상단 타이틀 바.
    final titleBarH = h * _titleBarFrac;
    final titleBarRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        borderThickness * 2,
        borderThickness * 2,
        w - borderThickness * 4,
        titleBarH,
      ),
      Radius.circular(h * 0.02),
    );
    final titleBarPaint = Paint()
      ..color = frameColor.withValues(alpha: 0.35);
    canvas.drawRRect(titleBarRect, titleBarPaint);

    if (title.isNotEmpty) {
      _drawText(
        canvas,
        title,
        Offset(
          borderThickness * 2 + h * 0.02,
          borderThickness * 2 + titleBarH / 2,
        ),
        h * 0.045,
        FontWeight.bold,
        Colors.white,
        maxWidth: w - borderThickness * 4 - h * 0.04,
      );
    }

    // 하단 정보 바.
    final bottomBarH = h * _bottomBarFrac;
    final bottomBarTop = h - borderThickness * 2 - bottomBarH;
    final bottomBarRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        borderThickness * 2,
        bottomBarTop,
        w - borderThickness * 4,
        bottomBarH,
      ),
      Radius.circular(h * 0.02),
    );
    final bottomBarPaint = Paint()
      ..color = frameColor.withValues(alpha: 0.40);
    canvas.drawRRect(bottomBarRect, bottomBarPaint);

    // 래리티 라벨 (좌측 하단).
    _drawText(
      canvas,
      rarity.label,
      Offset(
        borderThickness * 2 + h * 0.02,
        bottomBarTop + bottomBarH * 0.3,
      ),
      h * 0.035,
      FontWeight.w700,
      Colors.white.withValues(alpha: 0.95),
      maxWidth: w * 0.5,
    );

    // 서브타이틀 (우측 하단).
    if (subtitle.isNotEmpty) {
      _drawText(
        canvas,
        subtitle,
        Offset(
          w - borderThickness * 2 - h * 0.02,
          bottomBarTop + bottomBarH * 0.3,
        ),
        h * 0.03,
        FontWeight.normal,
        Colors.white.withValues(alpha: 0.85),
        maxWidth: w * 0.4,
        align: TextAlign.right,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset anchor,
    double fontSize,
    FontWeight weight,
    Color color, {
    double maxWidth = double.infinity,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          fontFamily: 'Roboto',
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    final dx = align == TextAlign.right
        ? anchor.dx - tp.width
        : anchor.dx;
    final dy = anchor.dy - tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant FramePainter old) =>
      old.rarity != rarity ||
      old.title != title ||
      old.subtitle != subtitle;
}
