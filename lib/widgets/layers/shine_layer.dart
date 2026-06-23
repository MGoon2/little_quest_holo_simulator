import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/card_data.dart';

/// 홀로그래픽 포일 레이어.
///
/// 두 가지 모드를 지원:
/// 1. **셰이더 홀로** (기본): holoImagePath 가 null 이면 GLSL Fragment Shader 로
///    래리티별 프로시저럴 홀로 효과를 GPU 에서 렌더링.
/// 2. **이미지 홀로** (사용자 선택): holoImagePath 가 있으면 사용자가 선택한
///    홀로 시트 이미지를 ImageShader 로 타일링하여 렌더링.
///
/// [pointerX], [pointerY] 는 0.0~1.0 정규화 좌표.
/// [opacity] 는 마우스 진입 시 1, 이탈 시 0 으로 페이드.
class ShineLayer extends StatefulWidget {
  const ShineLayer({
    super.key,
    required this.rarity,
    required this.pointerX,
    required this.pointerY,
    required this.opacity,
    this.intensity = 0.6,
    this.holoImagePath,
  });

  final Rarity rarity;
  final double pointerX; // 0~1
  final double pointerY; // 0~1
  final double opacity;
  final double intensity; // 0~1, 홀로 효과 강도
  final String? holoImagePath; // 사용자 홀로 이미지 (null이면 셰이더)

  @override
  State<ShineLayer> createState() => _ShineLayerState();
}

class _ShineLayerState extends State<ShineLayer> {
  // 셰이더 홀로용.
  ui.FragmentProgram? _program;
  bool _shaderLoaded = false;

  // 이미지 홀로용.
  ui.Image? _holoImage;
  bool _imageLoaded = false;
  String? _loadedImagePath;

  // Ticker 를 사용하지 않음.
  // 매 프레임 setState 가 부모를 rebuild 하여 사진 이미지가 흔들리는 원인.
  // 홀로 효과는 마우스 위치(pointerX/Y, opacity) 변화에 의해서만 repaint 됨.
  // 시간 기반 애니메이션은 마우스 진입 시점의 timestamp 를 사용.
  int _time = 0;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  @override
  void didUpdateWidget(ShineLayer old) {
    super.didUpdateWidget(old);
    // 홀로 이미지가 변경되면 다시 로드.
    if (widget.holoImagePath != _loadedImagePath) {
      _imageLoaded = false;
      _holoImage?.dispose();
      _holoImage = null;
      _loadHoloImage();
    }
    // 마우스 진입 시 시간 업데이트 (애니메이션 시작점).
    if (old.opacity <= 0.001 && widget.opacity > 0.001) {
      _time = DateTime.now().millisecondsSinceEpoch;
    }
  }

  Future<void> _loadShader() async {
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/holo.frag');
      if (mounted) setState(() => _shaderLoaded = true);
    } catch (e) {
      debugPrint('Failed to load holo shader: $e');
    }
  }

  Future<void> _loadHoloImage() async {
    final path = widget.holoImagePath;
    if (path == null) return;
    _loadedImagePath = path;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _holoImage = frame.image;
      codec.dispose();
      if (mounted) setState(() => _imageLoaded = true);
    } catch (e) {
      debugPrint('Failed to load holo image: $e');
    }
  }

  @override
  void dispose() {
    _holoImage?.dispose();
    super.dispose();
  }

  int get _rarityIndex {
    switch (widget.rarity) {
      case Rarity.basic:
        return 0;
      case Rarity.regularHolo:
        return 1;
      case Rarity.reverseHolo:
        return 2;
      case Rarity.illustrationRare:
        return 3;
      case Rarity.hyperRare:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.rarity.hasHolo || widget.opacity <= 0.001) {
      return const SizedBox.shrink();
    }

    // 이미지 홀로 모드.
    if (widget.holoImagePath != null) {
      if (!_imageLoaded) {
        // 이미지가 아직 로드되지 않았으면 로드 시작.
        if (!_imageLoaded && _holoImage == null && _loadedImagePath != widget.holoImagePath) {
          _loadHoloImage();
        }
        return const SizedBox.shrink();
      }
      return Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _ImageHoloPainter(
              image: _holoImage!,
              pointerX: widget.pointerX,
              pointerY: widget.pointerY,
              opacity: widget.opacity,
              intensity: widget.intensity,
              time: _time.toDouble(),
            ),
          ),
        ),
      );
    }

    // 셰이더 홀로 모드.
    if (!_shaderLoaded) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _ShaderPainter(
            program: _program!,
            pointerX: widget.pointerX,
            pointerY: widget.pointerY,
            opacity: widget.opacity,
            rarityIndex: _rarityIndex,
            time: _time.toDouble(),
            cardAspect: 2.5 / 3.5,
            intensity: widget.intensity,
          ),
        ),
      ),
    );
  }
}

/// 사용자 홀로 이미지를 ImageShader 로 타일링하여 렌더링하는 Painter.
class _ImageHoloPainter extends CustomPainter {
  _ImageHoloPainter({
    required this.image,
    required this.pointerX,
    required this.pointerY,
    required this.opacity,
    required this.intensity,
    required this.time,
  });

  final ui.Image image;
  final double pointerX;
  final double pointerY;
  final double opacity;
  final double intensity;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final src = Rect.fromLTWH(0, 0, imgW, imgH);
    final dst = Offset.zero & size;

    canvas.save();
    canvas.clipRect(dst);

    // ─── 다중 레이어 합성 (셰이더 홀로와 동일한 방식) ───────

    // [레이어 1] 홀로 PNG 베이스 — colorDodge 로 카드에 합성.
    // 홀로는 카드에 정확히 맞춰 그린다 (parallax 없음).
    // 카드가 기울어지면 홀로도 카드와 함께 움직인다.
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()
        ..blendMode = BlendMode.colorDodge
        ..colorFilter = ColorFilter.matrix([
          intensity, 0, 0, 0, 0,
          0, intensity, 0, 0, 0,
          0, 0, intensity, 0, 0,
          0, 0, 0, opacity, 0,
        ]),
    );

    // [레이어 2] 무지개 스펙트럼 오버레이 — 커서 위치에 따라 흐르는 색상.
    // 홀로 텍스처는 고정하고 색상만 커서를 따라 이동하여 입체감 표현.
    final spectrumShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        HSVColor.fromAHSV(0.3 * intensity * opacity, (pointerX * 360) % 360, 0.9, 0.6).toColor(),
        HSVColor.fromAHSV(0.3 * intensity * opacity, (pointerX * 360 + 90) % 360, 0.9, 0.6).toColor(),
        HSVColor.fromAHSV(0.3 * intensity * opacity, (pointerX * 360 + 180) % 360, 0.9, 0.6).toColor(),
        HSVColor.fromAHSV(0.3 * intensity * opacity, (pointerX * 360 + 270) % 360, 0.9, 0.6).toColor(),
      ],
    ).createShader(dst);
    canvas.drawRect(
      dst,
      Paint()
        ..shader = spectrumShader
        ..blendMode = BlendMode.overlay,
    );

    // [레이어 3] 커서 글로우 — softLight 로 부드러운 하이라이트.
    final glowShader = RadialGradient(
      center: Alignment(pointerX * 2 - 1, pointerY * 2 - 1),
      radius: 0.5,
      colors: [
        Colors.white.withValues(alpha: 0.6 * intensity * opacity),
        Colors.white.withValues(alpha: 0.0),
      ],
    ).createShader(dst);
    canvas.drawRect(
      dst,
      Paint()
        ..shader = glowShader
        ..blendMode = BlendMode.softLight,
    );

    // [레이어 4] 전체 밝기 증가 — plus 로 홀로를 더 밝게.
    canvas.drawRect(
      dst,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08 * intensity * opacity)
        ..blendMode = BlendMode.plus,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ImageHoloPainter old) =>
      old.pointerX != pointerX ||
      old.pointerY != pointerY ||
      old.opacity != opacity ||
      old.intensity != intensity ||
      (time - old.time).abs() > 0.001;
}

/// 셰이더 기반 홀로 Painter.
class _ShaderPainter extends CustomPainter {
  _ShaderPainter({
    required this.program,
    required this.pointerX,
    required this.pointerY,
    required this.opacity,
    required this.rarityIndex,
    required this.time,
    required this.cardAspect,
    required this.intensity,
  });

  final ui.FragmentProgram program;
  final double pointerX;
  final double pointerY;
  final double opacity;
  final int rarityIndex;
  final double time;
  final double cardAspect;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    // uniform 순서는 .frag 파일의 선언 순서와 일치해야 함.
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, pointerX);
    shader.setFloat(3, pointerY);
    shader.setFloat(4, opacity);
    shader.setFloat(5, rarityIndex.toDouble());
    shader.setFloat(6, time);
    shader.setFloat(7, cardAspect);
    shader.setFloat(8, intensity);

    final paint = Paint()
      ..shader = shader
      ..blendMode = BlendMode.plus;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ShaderPainter old) =>
      old.pointerX != pointerX ||
      old.pointerY != pointerY ||
      old.opacity != opacity ||
      old.rarityIndex != rarityIndex ||
      old.intensity != intensity ||
      (time - old.time).abs() > 0.001;
}
