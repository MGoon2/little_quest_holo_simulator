import 'dart:math' as math;

/// 마우스 포인터 위치를 카드 3D 회전값 / 홀로 배경 위치 / 글레어 위치로 변환.
///
/// 원본 pokemon-cards-css 의 Card.svelte 수식을 차용:
///   percent.x = (100 / width)  * absoluteX
///   percent.y = (100 / height) * absoluteY
///   center.x  = percent.x - 50
///   center.y  = percent.y - 50
///   rotateY   = -(center.x / 3.5)
///   rotateX   =  (center.y / 2)
///   backgroundX = adjust(percent.x, 0, 100, 37, 63)  // 회전보다 적게 이동
///
/// 입력 [pointer] 은 0.0~1.0 범위의 정규화된 좌표이다.
class PointerMath {
  PointerMath._();

  /// 정규화 포인터(0~1) → rotateY (도 단위, 좌우).
  static double rotateYFromX(double nx) {
    final center = (nx - 0.5) * 100; // -50 ~ 50
    return -center / 3.5;
  }

  /// 정규화 포인터(0~1) → rotateX (도 단위, 상하).
  static double rotateXFromY(double ny) {
    final center = (ny - 0.5) * 100;
    return center / 2;
  }

  /// 정규화 포인터(0~1) → 홀로 배경 위치(0~1).
  /// 회전보다 적게 이동하도록 0.37~0.63 범위로 매핑.
  static double backgroundFrom(double n) {
    return _adjust(n, 0.0, 1.0, 0.37, 0.63);
  }

  /// 중심으로부터의 거리 (0~1). 글레어 강도에 사용.
  static double distanceFromCenter(double nx, double ny) {
    final dx = nx - 0.5;
    final dy = ny - 0.5;
    return math.min(1.0, math.sqrt(dx * dx + dy * dy) * 2);
  }

  /// [t] 가 [min..max] 일 때 [outMin..outMax] 로 선형 매핑.
  static double _adjust(
    double t,
    double min,
    double max,
    double outMin,
    double outMax,
  ) {
    final clamped = t.clamp(min, max);
    final ratio = (clamped - min) / (max - min);
    return outMin + ratio * (outMax - outMin);
  }
}
