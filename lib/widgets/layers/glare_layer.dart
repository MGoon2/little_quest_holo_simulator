import 'package:flutter/material.dart';

/// 커서 위치를 추적하는 글레어(반사광) 레이어.
///
/// 원본 pokemon-cards-css 의 .card__glare 에 해당.
/// radial-gradient 로 커서 위치에서 빛나는 spotlight 효과를 만들고,
/// BlendMode.softLight 로 카드 위에 합성한다.
///
/// [pointerX], [pointerY] 는 0.0~1.0 정규화 좌표.
/// [opacity] 는 마우스 진입 시 1, 이탈 시 0 으로 페이드.
///
/// **주의**: Opacity 위젯으로 감싸면 BlendMode 가 오프스크린 버퍼에
/// 블렌드되어 색상이 변하는 현상이 발생한다. 대신 opacity 를 페인터
/// 내부에서 Paint 의 color alpha 로 직접 적용한다.
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

    // Opacity 위젯 사용 금지 — BlendMode 가 깨짐.
    // 대신 opacity 를 페인터에 전달하여 color alpha 로 적용.
    return SizedBox.expand(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _GlarePainter(
            pointerX: pointerX,
            pointerY: pointerY,
            opacity: opacity.clamp(0.0, 1.0),
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
    required this.opacity,
  });

  final double pointerX;
  final double pointerY;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Alignment(pointerX * 2 - 1, pointerY * 2 - 1);

    // 메인 글레어 — softLight 로 카드 위에 부드러운 반사광.
    // opacity 를 color alpha 에 직접 적용 (Opacity 위젯 사용 안 함).
    final glareShader = RadialGradient(
      center: center,
      radius: 0.9,
      colors: [
        Color.fromRGBO(255, 255, 255, 0.6 * opacity),
        Color.fromRGBO(153, 153, 153, 0.33 * opacity),
        Color.fromRGBO(0, 0, 0, 0),
      ],
      stops: const [0.0, 0.35, 1.0],
    ).createShader(Offset.zero & size);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = glareShader
        ..blendMode = BlendMode.softLight,
    );

    // 커서 중심 하이라이트 — overlay 로 밝은 점.
    final highlightShader = RadialGradient(
      center: center,
      radius: 0.25,
      colors: [
        Color.fromRGBO(255, 255, 255, 0.8 * opacity),
        Color.fromRGBO(255, 255, 255, 0),
      ],
    ).createShader(Offset.zero & size);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = highlightShader
        ..blendMode = BlendMode.overlay,
    );
  }

  @override
  bool shouldRepaint(covariant _GlarePainter old) =>
      old.pointerX != pointerX ||
      old.pointerY != pointerY ||
      old.opacity != opacity;
}
