import 'dart:io';
import 'dart:math' as math;

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
  // 정규화 포인터 (0~1). 0.5 = 중심.
  double _px = 0.5;
  double _py = 0.5;
  bool _hovering = false;

  // 글레어/홀로 가시성 (0~1).
  double _fx = 0.0;

  late final AnimationController _anim;
  Animation<double>? _fxAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        if (_fxAnim == null) return;
        setState(() {
          _fx = _fxAnim!.value;
          // spring-back 시 포인터도 중심으로 복귀.
          if (!_hovering) {
            _px = 0.5 + (_px - 0.5) * (1 - _fxAnim!.value);
            _py = 0.5 + (_py - 0.5) * (1 - _fxAnim!.value);
          }
        });
      });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onHover(PointerHoverEvent e, Rect cardRect) {
    final nx = ((e.position.dx - cardRect.left) / cardRect.width)
        .clamp(0.0, 1.0);
    final ny = ((e.position.dy - cardRect.top) / cardRect.height)
        .clamp(0.0, 1.0);
    setState(() {
      _px = nx;
      _py = ny;
    });
  }

  void _onEnter() {
    if (_hovering) return;
    setState(() => _hovering = true);
    _fxAnim = Tween<double>(begin: _fx, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _anim.forward(from: 0);
  }

  void _onExit() {
    if (!_hovering) return;
    setState(() => _hovering = false);
    _fxAnim = Tween<double>(begin: _fx, end: 0.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w / FramePainter.aspectRatio;

    // 3D 회전값.
    final rotY = PointerMath.rotateYFromX(_px);
    final rotX = PointerMath.rotateXFromY(_py);

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0015) // perspective
      ..rotateX(rotX * _fx * (math.pi / 180))
      ..rotateY(rotY * _fx * (math.pi / 180));

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
          child: Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: _buildCardStack(w, h),
          ),
        ),
      ),
    );
  }

  Widget _buildCardStack(double w, double h) {
    final data = widget.data;
    final cardRadius = h * 0.035;

    // 그림자는 클립 밖에서 표시되어야 하므로 외부 Container 로 분리.
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
      // Stack 전체를 카드 모양(둥근 모서리)으로 클립하여
      // 홀로/글레어 레이어가 카드 영역 밖으로 튀어나가지 않도록 함.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // [0] 카드 베이스 (어두운 배경).
            Container(color: const Color(0xFF1A1A1A)),

            // [1] 사진 이미지 (사용자가 선택한 직접 촬영 사진).
            // RepaintBoundary 로 감싸서 홀로/글레어 애니메이션이
            // 사진을 매 프레임 재페인트하지 않도록 격리.
            RepaintBoundary(
              child: Padding(
                padding: EdgeInsets.all(h * 0.025),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(h * 0.02),
                  child: Image.file(
                    File(data.imagePath),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    cacheWidth: (w * 2).toInt(),
                    cacheHeight: (h * 2).toInt(),
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF2A2A2A),
                      child: const Center(
                        child:
                            Icon(Icons.broken_image, color: Colors.white54),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // [2] 홀로 포일 레이어.
            ShineLayer(
              rarity: data.rarity,
              pointerX: _px,
              pointerY: _py,
              opacity: _fx,
              intensity: 0.8,
              holoImagePath: data.holoImagePath,
            ),

            // [3] 글레어 레이어.
            GlareLayer(
              pointerX: _px,
              pointerY: _py,
              opacity: _fx,
            ),

            // [4] 오리지널 카드 프레임.
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

