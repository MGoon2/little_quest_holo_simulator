import 'package:flutter/material.dart';

/// 커서 위치를 추적하는 글레어(반사광) 레이어.
///
/// 원본 pokemon-cards-css 의 .card__glare 에 해당.
/// radial-gradient 로 커서 위치에서 빛나는 spotlight 효과를 만들고,
/// BlendMode.softLight 로 카드 위에 합성한다.
///
/// [pointerX], [pointerY] 는 0.0~1.0 정규화 좌표.
/// [opacity] 는 마우스 진입 시 1, 이탈 시 0 으로 페이드.
class GlareLayer extends StatelessWidget {
  const GlareLayer({
    super.key,
    required this.pointerX,
    required this.pointerY,
    required this.opacity,
  });

  final double pointerX;
  final double pointerY;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.001) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: CustomPaint(
            painter: _GlarePainter(
              pointerX: pointerX,
              pointerY: pointerY,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlarePainter extends CustomPainter {
  _GlarePainter({
    required this.pointerX,
    required this.pointerY,
  });

  final double pointerX;
  final double pointerY;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = RadialGradient(
      center: Alignment(
        pointerX * 2 - 1,
        pointerY * 2 - 1,
      ),
      radius: 0.9,
      colors: const [
        Color(0x99FFFFFF),
        Color(0x55999999),
        Color(0x00000000),
      ],
      stops: const [0.0, 0.35, 1.0],
    ).createShader(Offset.zero & size);

    final paint = Paint()
      ..shader = shader
      ..blendMode = BlendMode.softLight;
    canvas.drawRect(Offset.zero & size, paint);

    // 추가 하이라이트 (커서 중심의 작은 밝은 점).
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          pointerX * 2 - 1,
          pointerY * 2 - 1,
        ),
        radius: 0.25,
        colors: const [
          Color(0xCCFFFFFF),
          Color(0x00FFFFFF),
        ],
      ).createShader(Offset.zero & size)
      ..blendMode = BlendMode.overlay;
    canvas.drawRect(Offset.zero & size, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _GlarePainter old) =>
      old.pointerX != pointerX || old.pointerY != pointerY;
}
