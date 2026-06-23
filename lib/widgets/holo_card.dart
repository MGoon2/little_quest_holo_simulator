import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerHoverEvent;
import 'package:flutter/material.dart';

import '../models/card_data.dart';
import '../painters/frame_painter.dart';
import '../utils/pointer_math.dart';
import 'layers/glare_layer.dart';
import 'layers/shine_layer.dart';

/// 홀로그래픽 트레이딩 카드 위젯.
///
/// 원본 pokemon-cards-css 의 Card.svelte 에 해당.
/// - MouseRegion 으로 커서 위치 추적
/// - Transform + Matrix4 로 3D 틸트
/// - Stack 으로 사진 / 프레임 / 홀로 포일 / 글레어 레이어 합성
/// - 마우스 이탈 시 spring-back 애니메이션
///
/// **흔들림 방지 핵심**:
/// Image.file 위젯을 사용하면 매 rebuild 마다 이미지가 재구성되어 흔들린다.
/// 대신 사진을 미리 로드하여 ui.Image 로 저장하고 CustomPaint 로 그린다.
/// CustomPainter 의 shouldRepaint 가 false 를 반환하면 절대 다시 그려지지 않는다.
class HoloCard extends StatefulWidget {
  const HoloCard({
    super.key,
    required this.data,
    this.width = 300,
    this.onTap,
    this.onLongPress,
  });

  final CardData data;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<HoloCard> createState() => _HoloCardState();
}

class _HoloCardState extends State<HoloCard>
    with SingleTickerProviderStateMixin {
  // 포인터/페이드 값을 ValueNotifier 로 관리.
  final _pointerX = ValueNotifier<double>(0.5);
  final _pointerY = ValueNotifier<double>(0.5);
  final _fade = ValueNotifier<double>(0.0);
  bool _hovering = false;

  // 사진을 미리 로드하여 ui.Image 로 저장.
  // Image.file 위젯 대신 CustomPaint 로 그려 흔들림 방지.
  ui.Image? _photoImage;
  bool _photoError = false;

  late final AnimationController _anim;
  Animation<double>? _fadeAnim;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        if (_fadeAnim == null) return;
        _fade.value = _fadeAnim!.value;
        if (!_hovering) {
          _pointerX.value =
              0.5 + (_pointerX.value - 0.5) * (1 - _fadeAnim!.value);
          _pointerY.value =
              0.5 + (_pointerY.value - 0.5) * (1 - _fadeAnim!.value);
        }
      });
  }

  Future<void> _loadPhoto() async {
    try {
      final bytes = await File(widget.data.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _photoImage = frame.image;
      codec.dispose();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to load photo: $e');
      if (mounted) setState(() => _photoError = true);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _pointerX.dispose();
    _pointerY.dispose();
    _fade.dispose();
    _photoImage?.dispose();
    super.dispose();
  }

  void _onHover(PointerHoverEvent e, Rect cardRect) {
    final nx = ((e.position.dx - cardRect.left) / cardRect.width)
        .clamp(0.0, 1.0);
    final ny = ((e.position.dy - cardRect.top) / cardRect.height)
        .clamp(0.0, 1.0);
    _pointerX.value = nx;
    _pointerY.value = ny;
  }

  void _onEnter() {
    if (_hovering) return;
    _hovering = true;
    _fadeAnim = Tween<double>(begin: _fade.value, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _anim.forward(from: 0);
  }

  void _onExit() {
    if (!_hovering) return;
    _hovering = false;
    _fadeAnim = Tween<double>(begin: _fade.value, end: 0.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w / FramePainter.aspectRatio;

    return MouseRegion(
      onHover: (e) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final box = renderBox.localToGlobal(Offset.zero);
        final cardRect = box & renderBox.size;
        _onHover(e, cardRect);
      },
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: SizedBox(
          width: w,
          height: h,
          // 3D 틸트: AnimatedBuilder 로 포인터+페이드 감시.
          // child (사진/프레임) 는 rebuild 되지 않음.
          child: AnimatedBuilder(
            animation: Listenable.merge([_pointerX, _pointerY, _fade]),
            builder: (context, child) {
              final fx = _fade.value;
              final px = _pointerX.value;
              final py = _pointerY.value;
              final rotY = PointerMath.rotateYFromX(px);
              final rotX = PointerMath.rotateXFromY(py);

              final matrix = Matrix4.identity()
                ..setEntry(3, 2, 0.0015) // perspective
                ..rotateX(rotX * fx * (math.pi / 180))
                ..rotateY(rotY * fx * (math.pi / 180));

              return Transform(
                alignment: Alignment.center,
                transform: matrix,
                child: child,
              );
            },
            child: _buildCardStack(w, h),
          ),
        ),
      ),
    );
  }

  /// 카드 Stack. AnimatedBuilder 의 child 로 전달되어
  /// 포인터/페이드 값이 변해도 절대 rebuild 되지 않음.
  Widget _buildCardStack(double w, double h) {
    final data = widget.data;
    final cardRadius = h * 0.035;
    final photoPadding = h * 0.015;  // 이미지 영역 넓히기 (여백 감소)
    final photoRadius = h * 0.015;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // [0] 카드 베이스.
            Container(color: const Color(0xFF1A1A1A)),

            // [1] 사진 이미지.
            // Image.file 대신 CustomPaint 로 그려 흔들림 방지.
            // 사진은 한 번 로드된 ui.Image 로 저장되며,
            // _PhotoPainter.shouldRepaint 가 false 를 반환하여
            // 절대 다시 그려지지 않음.
            Padding(
              padding: EdgeInsets.all(photoPadding),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(photoRadius),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _PhotoPainter(
                    image: _photoImage,
                    hasError: _photoError,
                  ),
                ),
              ),
            ),

            // [2] 홀로 포일 레이어.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_pointerX, _pointerY, _fade]),
                builder: (context, _) {
                  final fx = _fade.value;
                  if (fx <= 0.001) return const SizedBox.shrink();
                  return ShineLayer(
                    rarity: data.rarity,
                    pointerX: _pointerX.value,
                    pointerY: _pointerY.value,
                    opacity: fx,
                    intensity: 0.8,
                    holoImagePath: data.holoImagePath,
                  );
                },
              ),
            ),

            // [3] 글레어 레이어.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_pointerX, _pointerY, _fade]),
                builder: (context, _) {
                  final fx = _fade.value;
                  if (fx <= 0.001) return const SizedBox.shrink();
                  return GlareLayer(
                    pointerX: _pointerX.value,
                    pointerY: _pointerY.value,
                    opacity: fx,
                  );
                },
              ),
            ),

            // [4] 카드 프레임.
            CustomPaint(
              painter: FramePainter(
                rarity: data.rarity,
                title: data.title,
                subtitle: data.subtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 사진을 ui.Image 에서 직접 그리는 Painter.
/// shouldRepaint 가 항상 false → 절대 다시 그려지지 않음 → 흔들림 없음.
class _PhotoPainter extends CustomPainter {
  _PhotoPainter({
    required this.image,
    required this.hasError,
  });

  final ui.Image? image;
  final bool hasError;

  @override
  void paint(Canvas canvas, Size size) {
    if (hasError || image == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF2A2A2A),
      );
      // 에러 아이콘은 텍스트로 대체 불가능하므로 단순히 어두운 배경만 표시.
      return;
    }

    final imgW = image!.width.toDouble();
    final imgH = image!.height.toDouble();
    final src = Rect.fromLTWH(0, 0, imgW, imgH);

    // BoxFit.cover 계산.
    final imgAspect = imgW / imgH;
    final dstAspect = size.width / size.height;
    Rect drawRect;
    if (imgAspect > dstAspect) {
      // 이미지가 더 넓음 → 높이에 맞추고 너비 자름.
      final scale = size.height / imgH;
      final scaledW = imgW * scale;
      final dx = (size.width - scaledW) / 2;
      drawRect = Rect.fromLTWH(dx, 0, scaledW, size.height);
    } else {
      // 이미지가 더 높음 → 너비에 맞추고 높이 자름.
      final scale = size.width / imgW;
      final scaledH = imgH * scale;
      final dy = (size.height - scaledH) / 2;
      drawRect = Rect.fromLTWH(0, dy, size.width, scaledH);
    }

    canvas.drawImageRect(image!, src, drawRect, Paint());
  }

  @override
  bool shouldRepaint(covariant _PhotoPainter old) {
    // 이미지가 변경된 경우에만 다시 그림.
    // 포인터 이동 시에는 절대 다시 그려지지 않음.
    return old.image != image || old.hasError != hasError;
  }
}
