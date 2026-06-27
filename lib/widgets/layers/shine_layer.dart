import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

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
    this.intensity = 0.7,
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

  // 테스트 멀티레이어 홀로용 (assets/holo_test/).
  // 00: 마스크, 01: 색상, 02: 패턴, 03: 스파클, 04: 글레어, 05: 엣지
  // 06: 카드 전체 포일 패턴, 07: 카드 전체 스파클
  final List<ui.Image?> _testLayers = List.filled(8, null);
  bool _testLayersLoaded = false;
  static const _testAssetPaths = [
    'assets/holo_test/00_foreground_alpha_mask.png',
    'assets/holo_test/01_holo_color_overlay.png',
    'assets/holo_test/02_foil_pattern_overlay.png',
    'assets/holo_test/03_sparkle_overlay.png',
    'assets/holo_test/04_glare_overlay.png',
    'assets/holo_test/05_edge_highlight_mask_overlay.png',
    'assets/holo_test/02_foil_pattern_overlay_cardwide.png',
    'assets/holo_test/03_sparkle_overlay_cardwide.png',
  ];

  // Ticker 를 사용하지 않음.
  // 매 프레임 setState 가 부모를 rebuild 하여 사진 이미지가 흔들리는 원인.
  // 홀로 효과는 마우스 위치(pointerX/Y, opacity) 변화에 의해서만 repaint 됨.
  // 시간 기반 애니메이션은 마우스 진입 시점의 timestamp 를 사용.
  int _time = 0;

  @override
  void initState() {
    super.initState();
    if (widget.rarity == Rarity.testHolo) {
      _loadTestLayers();
    } else {
      _loadShader();
    }
  }

  @override
  void didUpdateWidget(ShineLayer old) {
    super.didUpdateWidget(old);
    // 래리티가 testHolo로 변경되면 테스트 레이어 로드.
    if (widget.rarity == Rarity.testHolo && !_testLayersLoaded && _testLayers.every((i) => i == null)) {
      _loadTestLayers();
    }
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

  Future<void> _loadTestLayers() async {
    try {
      for (int i = 0; i < _testAssetPaths.length; i++) {
        final bytes = await rootBundle.load(_testAssetPaths[i]);
        final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        _testLayers[i] = frame.image;
        codec.dispose();
      }
      if (mounted) setState(() => _testLayersLoaded = true);
    } catch (e) {
      debugPrint('Failed to load test holo layers: $e');
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
    for (final img in _testLayers) {
      img?.dispose();
    }
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
      case Rarity.testHolo:
        return 5;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.rarity.hasHolo || widget.opacity <= 0.001) {
      return const SizedBox.shrink();
    }

    // 테스트 멀티레이어 홀로 모드 (assets/holo_test/ 6장 합성).
    if (widget.rarity == Rarity.testHolo) {
      if (!_testLayersLoaded) return const SizedBox.shrink();
      return SizedBox.expand(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _TestHoloPainter(
              mask: _testLayers[0]!,
              color: _testLayers[1]!,
              pattern: _testLayers[2]!,
              sparkle: _testLayers[3]!,
              glare: _testLayers[4]!,
              edge: _testLayers[5]!,
              patternCardwide: _testLayers[6]!,
              sparkleCardwide: _testLayers[7]!,
              pointerX: widget.pointerX,
              pointerY: widget.pointerY,
              opacity: widget.opacity,
              intensity: widget.intensity,
            ),
          ),
        ),
      );
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
      return SizedBox.expand(
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
    return SizedBox.expand(
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

    // 포인터-중심 거리 (0~1). 원본 CSS 의 --pointer-from-center.
    final dx = pointerX - 0.5;
    final dy = pointerY - 0.5;
    final pfc = math.min(1.0, math.sqrt(dx * dx + dy * dy) * 2);

    // 포인터 거리 기반 밝기 (원본 CSS: brightness(pfc * 0.4 + 0.4)).
    final brightness = intensity * (pfc * 0.4 + 0.4);

    // 홀로 이미지를 카드 영역에 정확히 맞춰 그린다.
    // 시차(parallax) 없음 — 홀로는 카드와 함께 움직인다.
    // 깊이감은 blendMode + 포인터 거리 밝기 변화로만 표현.
    final src = Rect.fromLTWH(0, 0, imgW, imgH);
    final dst = Offset.zero & size;

    // 카드 영역만 클립.
    canvas.save();
    canvas.clipRect(dst);

    // ─── 다중 레이어 합성 ────────────────────────────────────

    // [레이어 1] 홀로 PNG 베이스 — colorDodge 로 카드에 합성.
    // 홀로는 카드에 정확히 맞춰 그려지며 카드와 함께 움직인다.
    // 밝기는 포인터 거리에 따라 변화 (빛 반사각 시뮬레이션).
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()
        ..blendMode = BlendMode.colorDodge
        ..colorFilter = ColorFilter.matrix([
          brightness, 0, 0, 0, 0,
          0, brightness, 0, 0, 0,
          0, 0, brightness, 0, 0,
          0, 0, 0, opacity, 0,
        ]),
    );

    // [레이어 2] 무지개 스펙트럼 오버레이 — 커서 위치에 따라 흐르는 색상.
    // 스펙트럼은 카드 전체 영역에 그린다.
    final cardRect = Offset.zero & size;
    final spectrumShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        HSVColor.fromAHSV(0.3 * intensity * opacity, (pointerX * 360) % 360, 0.9, 0.6).toColor(),
        HSVColor.fromAHSV(0.3 * intensity * opacity, (pointerX * 360 + 90) % 360, 0.9, 0.6).toColor(),
        HSVColor.fromAHSV(0.3 * intensity * opacity, (pointerX * 360 + 180) % 360, 0.9, 0.6).toColor(),
        HSVColor.fromAHSV(0.3 * intensity * opacity, (pointerX * 360 + 270) % 360, 0.9, 0.6).toColor(),
      ],
    ).createShader(cardRect);
    canvas.drawRect(
      cardRect,
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
    ).createShader(cardRect);
    canvas.drawRect(
      cardRect,
      Paint()
        ..shader = glowShader
        ..blendMode = BlendMode.softLight,
    );

    // [레이어 4] 전체 밝기 증가 — plus 로 홀로를 더 밝게.
    canvas.drawRect(
      cardRect,
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

/// 테스트용 멀티레이어 홀로 Painter.
///
/// assets/holo_test/ 의 6장 이미지를 합성:
/// [00] 마스크: 홀로 효과가 나타날 영역 정의 (L 그레이스케일).
/// [01] 색상: 홀로 색상 오버레이 (colorDodge).
/// [02] 패턴: 홀로 포일 패턴 (overlay).
/// [03] 스파클: 글리터/반짝임 (plus).
/// [04] 글레어: 커서 반사광 (softLight, 커서 위치 추적).
/// [05] 엣지: 엣지 하이라이트 (screen).
/// [06] 카드 전체 포일 패턴 (overlay, 마스크 없이 카드 전체).
/// [07] 카드 전체 스파클 (plus, 마스크 없이 카드 전체).
///
/// 커서 위치에 따라 글레어가 이동하고, 전체 밝기가 포인터-중심 거리에
/// 따라 변화한다.
class _TestHoloPainter extends CustomPainter {
  _TestHoloPainter({
    required this.mask,
    required this.color,
    required this.pattern,
    required this.sparkle,
    required this.glare,
    required this.edge,
    required this.patternCardwide,
    required this.sparkleCardwide,
    required this.pointerX,
    required this.pointerY,
    required this.opacity,
    required this.intensity,
  });

  final ui.Image mask;
  final ui.Image color;
  final ui.Image pattern;
  final ui.Image sparkle;
  final ui.Image glare;
  final ui.Image edge;
  final ui.Image patternCardwide;
  final ui.Image sparkleCardwide;
  final double pointerX;
  final double pointerY;
  final double opacity;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    // 포인터-중심 거리 (0~1).
    final dx = pointerX - 0.5;
    final dy = pointerY - 0.5;
    final pfc = math.min(1.0, math.sqrt(dx * dx + dy * dy) * 2);

    // 포인터 거리 기반 밝기.
    final brightness = intensity * (pfc * 0.4 + 0.4);

    final cardRect = Offset.zero & size;
    final src = Rect.fromLTWH(
      0,
      0,
      mask.width.toDouble(),
      mask.height.toDouble(),
    );

    canvas.save();
    canvas.clipRect(cardRect);

    // [01] 홀로 색상 오버레이 — colorDodge 로 카드에 합성.
    // 더 투명하게: opacity * 0.4 로 알파 감소.
    _drawWithMask(
      canvas,
      color,
      src,
      cardRect,
      mask,
      Paint()
        ..blendMode = BlendMode.colorDodge
        ..colorFilter = ColorFilter.matrix([
          brightness, 0, 0, 0, 0,
          0, brightness, 0, 0, 0,
          0, 0, brightness, 0, 0,
          0, 0, 0, opacity * 0.4, 0,
        ]),
    );

    // [02] 홀로 패턴 — overlay 로 포일 텍스처 추가.
    _drawWithMask(
      canvas,
      pattern,
      src,
      cardRect,
      mask,
      Paint()
        ..blendMode = BlendMode.overlay
        ..colorFilter = ColorFilter.matrix([
          brightness, 0, 0, 0, 0,
          0, brightness, 0, 0, 0,
          0, 0, brightness, 0, 0,
          0, 0, 0, opacity, 0,
        ]),
    );

    // [03] 스파클 — plus 로 글리터 효과.
    _drawWithMask(
      canvas,
      sparkle,
      src,
      cardRect,
      mask,
      Paint()
        ..blendMode = BlendMode.plus
        ..colorFilter = ColorFilter.matrix([
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, opacity * intensity, 0,
        ]),
    );

    // [04] 글레어 — 커서 위치를 따라 이동하는 반사광.
    // 글레어 이미지 자체에 alpha가 있으므로 커서 오프셋만 적용.
    final glareOffsetX = (pointerX - 0.5) * size.width * 0.15;
    final glareOffsetY = (pointerY - 0.5) * size.height * 0.15;
    final glareDst = cardRect.shift(Offset(glareOffsetX, glareOffsetY));
    canvas.drawImageRect(
      glare,
      src,
      glareDst,
      Paint()
        ..blendMode = BlendMode.softLight
        ..colorFilter = ColorFilter.matrix([
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, opacity * (0.5 + pfc * 0.5), 0,
        ]),
    );

    // [05] 엣지 하이라이트 — screen 로 엣지 강조.
    _drawWithMask(
      canvas,
      edge,
      src,
      cardRect,
      mask,
      Paint()
        ..blendMode = BlendMode.screen
        ..colorFilter = ColorFilter.matrix([
          brightness, 0, 0, 0, 0,
          0, brightness, 0, 0, 0,
          0, 0, brightness, 0, 0,
          0, 0, 0, opacity * 0.8, 0,
        ]),
    );

    // [06] 카드 전체 포일 패턴 — 마스크 없이 카드 전체에 overlay.
    // 기존 02 패턴은 마스크 영역에만 적용되지만,
    // cardwide 버전은 카드 전체에 포일 패턴을 깔아줌.
    canvas.drawImageRect(
      patternCardwide,
      Rect.fromLTWH(0, 0, patternCardwide.width.toDouble(),
          patternCardwide.height.toDouble()),
      cardRect,
      Paint()
        ..blendMode = BlendMode.overlay
        ..colorFilter = ColorFilter.matrix([
          brightness, 0, 0, 0, 0,
          0, brightness, 0, 0, 0,
          0, 0, brightness, 0, 0,
          0, 0, 0, opacity * 0.6, 0,
        ]),
    );

    // [07] 카드 전체 스파클 — 마스크 없이 카드 전체에 plus.
    // 기존 03 스파클은 마스크 영역에만 적용되지만,
    // cardwide 버전은 카드 전체에 글리터를 뿌려줌.
    canvas.drawImageRect(
      sparkleCardwide,
      Rect.fromLTWH(0, 0, sparkleCardwide.width.toDouble(),
          sparkleCardwide.height.toDouble()),
      cardRect,
      Paint()
        ..blendMode = BlendMode.plus
        ..colorFilter = ColorFilter.matrix([
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, opacity * intensity * 0.7, 0,
        ]),
    );

    canvas.restore();
  }

  /// 마스크 이미지로 클리핑한 후 image 를 그린다.
  /// 마스크(00)는 L(그레이스케일) 모드 — 밝은 영역이 홀로 효과 영역.
  /// 오프스크린 레이어를 사용하여 image 를 그린 후,
  /// 마스크의 밝기(L) 값을 알파로 매핑하여 dstIn 합성.
  void _drawWithMask(
    Canvas canvas,
    ui.Image image,
    Rect src,
    Rect dst,
    ui.Image maskImage,
    Paint paint,
  ) {
    // 오프스크린 레이어: image + mask 합성 후 캔버스에 그림.
    canvas.saveLayer(dst, Paint());

    // 1. 이미지를 지정된 blendMode 로 그림.
    canvas.drawImageRect(image, src, dst, paint);

    // 2. 마스크를 dstIn 으로 적용.
    //    마스크는 L(그레이스케일)이므로 R 채널 값을 알파로 매핑.
    //    ImageShader + ColorFilter 로 그레이스케일 → 알파 변환 후 dstIn.
    final maskMatrix = Float64List.fromList([
      dst.width / maskImage.width, 0, 0, 0,
      0, dst.height / maskImage.height, 0, 0,
      0, 0, 1, 0,
      dst.left, dst.top, 0, 1,
    ]);
    canvas.drawRect(
      dst,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ImageShader(
          maskImage,
          TileMode.clamp,
          TileMode.clamp,
          maskMatrix,
        )
        // L(그레이스케일)의 R 값을 알파로 매핑.
        ..colorFilter = const ColorFilter.matrix([
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          1, 0, 0, 0, 0, // R → Alpha
        ]),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TestHoloPainter old) =>
      old.pointerX != pointerX ||
      old.pointerY != pointerY ||
      old.opacity != opacity ||
      old.intensity != intensity;
}
