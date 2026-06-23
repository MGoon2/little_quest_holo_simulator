#version 460 core

#include <flutter/runtime_effect.glsl>

// ─── Uniforms ────────────────────────────────────────────────
// 인덱스 순서대로 setFloat() 호출해야 함.
//   0: uResolution.x
//   1: uResolution.y
//   2: uPointer.x   (0~1 정규화)
//   3: uPointer.y   (0~1 정규화)
//   4: uOpacity     (0~1, 마우스 진입 시 페이드)
//   5: uRarity      (0=basic, 1=regular, 2=reverse, 3=illustration, 4=hyper)
//   6: uTime        (초, 애니메이션용)
//   7: uCardAspect  (width/height, UV 보정용)
//   8: uIntensity   (0~1, 홀로 효과 강도 — 런타임 조정 가능)

uniform vec2  uResolution;
uniform vec2  uPointer;
uniform float uOpacity;
uniform float uRarity;
uniform float uTime;
uniform float uCardAspect;
uniform float uIntensity;

out vec4 fragColor;

// ─── 상수 ────────────────────────────────────────────────────
const float PI  = 3.14159265359;
const float TAU = 6.28318530718;

// ─── 유틸리티 ────────────────────────────────────────────────

// 해시 노이즈 (프로시저럴).
float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

// 밸류 노이즈 (부드러운 노이즈).
float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM (Fractal Brownian Motion) — 포일 텍스처용.
float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * valueNoise(p);
    p *= 2.0;
    a *= 0.5;
  }
  return v;
}

// HSV → RGB 변환.
vec3 hsv2rgb(vec3 c) {
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// ─── 블렌드 모드 시뮬레이션 ──────────────────────────────────

// Color Dodge: base / (1 - blend)
vec3 blendColorDodge(vec3 base, vec3 blend) {
  return base / (1.0 - blend + 0.001);
}

// Soft Light.
vec3 blendSoftLight(vec3 base, vec3 blend) {
  return mix(
    2.0 * base * blend,
    1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
    step(0.5, blend)
  );
}

// Overlay.
vec3 blendOverlay(vec3 base, vec3 blend) {
  return mix(
    2.0 * base * blend,
    1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
    step(0.5, base)
  );
}

// Hard Light.
vec3 blendHardLight(vec3 base, vec3 blend) {
  return mix(
    2.0 * base * blend,
    1.0 - 2.0 * (1.0 - blend) * (1.0 - base),
    step(0.5, blend)
  );
}

// Screen.
vec3 blendScreen(vec3 base, vec3 blend) {
  return 1.0 - (1.0 - base) * (1.0 - blend);
}

// ─── 홀로 패턴 생성 함수 ─────────────────────────────────────

// 무지개 스펙트럼 색상 (hue 0~1 → RGB).
vec3 spectrum(float h) {
  return hsv2rgb(vec3(fract(h), 0.85, 0.7));
}

// 정규 홀로: 수직 빔 + 스캔라인.
vec3 regularHolo(vec2 uv, vec2 pointer, float time) {
  // 배경 위치 (회전보다 적게 이동).
  vec2 bg = uv + (pointer - 0.5) * 0.15;

  // [레이어 1] 수직 무지개 빔 (repeating gradient).
  float beamPos = bg.x * 14.0 + time * 0.3;
  float beam = abs(fract(beamPos) - 0.5) * 2.0; // 0~1 삼각파
  vec3 beamColor = spectrum(bg.x * 1.2 + time * 0.05);
  vec3 layer1 = beamColor * smoothstep(0.0, 1.0, 1.0 - beam) * 0.6;

  // [레이어 2] 스캔라인 (미세 수직 라인).
  float scan = sin(uv.y * 600.0 + time * 2.0) * 0.5 + 0.5;
  vec3 layer2 = spectrum(bg.x + 0.3) * scan * 0.15;

  // [레이어 3] FBM 포일 텍스처 (미세 홀로 입자).
  float foil = fbm(uv * 8.0 + time * 0.1);
  vec3 layer3 = spectrum(foil + bg.x) * foil * 0.3;

  // 합성: colorDodge 로 레이어 겹침.
  vec3 result = layer1;
  result = blendColorDodge(result, layer2);
  result = blendColorDodge(result, layer3);

  return result;
}

// 역홀로: 코스모스(포켓볼) 패턴 + 전체 포일.
vec3 reverseHolo(vec2 uv, vec2 pointer, float time) {
  vec2 bg = uv + (pointer - 0.5) * 0.1;

  // [레이어 1] 코스모스 점 패턴 (벌집 구조).
  vec2 grid = bg * vec2(12.0, 18.0);
  vec2 cellId = floor(grid);
  vec2 cellUv = fract(grid) - 0.5;

  // 홀수 행은 절반 오프셋.
  if (mod(cellId.y, 2.0) == 1.0) cellUv.x -= 0.5;

  float dist = length(cellUv);
  float dot = smoothstep(0.45, 0.2, dist);

  float cellHue = (cellId.x + cellId.y) / 30.0 + bg.x * 0.3 + time * 0.02;
  vec3 layer1 = spectrum(cellHue) * dot * 0.7;

  // [레이어 2] 전체 포일 그래디언트.
  float foilGrad = sin(bg.x * PI + time * 0.5) * 0.5 + 0.5;
  vec3 layer2 = spectrum(bg.x * 0.8 + time * 0.03) * foilGrad * 0.2;

  // [레이어 3] FBM 미세 텍스처.
  float foil = fbm(uv * 12.0);
  vec3 layer3 = spectrum(foil * 0.5 + 0.3) * foil * 0.25;

  vec3 result = layer1;
  result = blendColorDodge(result, layer2);
  result = blendSoftLight(result, layer3);

  return result;
}

// 일러스트 레어: 대각선 그래디언트 + 노이즈 텍스처.
vec3 illustrationRare(vec2 uv, vec2 pointer, float time) {
  vec2 bg = uv + (pointer - 0.5) * 0.2;

  // [레이어 1] 대각선 무지개 그래디언트.
  float diag = (bg.x + bg.y) * 0.5;
  vec3 layer1 = spectrum(diag * 1.5 + time * 0.08) * 0.5;

  // [레이어 2] FBM 노이즈 텍스처 (포일 입자).
  float n = fbm(uv * 6.0 + time * 0.15);
  vec3 layer2 = spectrum(n + diag) * n * 0.4;

  // [레이어 3] 미세 글리터 (고주파 노이즈).
  float glitter = hash(floor(uv * 200.0));
  glitter = pow(glitter, 8.0);
  vec3 layer3 = spectrum(glitter + time * 0.1) * glitter * 0.8;

  // [레이어 4] 대각선 스캔라인.
  float scan = sin((uv.x + uv.y) * 300.0 + time) * 0.5 + 0.5;
  vec3 layer4 = spectrum(diag + 0.5) * scan * 0.1;

  vec3 result = layer1;
  result = blendColorDodge(result, layer2);
  result = blendColorDodge(result, layer3);
  result = blendOverlay(result, layer4);

  return result;
}

// 하이퍼 레어: 골드 에칭 + 이중 글리터.
vec3 hyperRare(vec2 uv, vec2 pointer, float time) {
  vec2 bg = uv + (pointer - 0.5) * 0.15;

  // [레이어 1] 골드 베이스 그래디언트.
  float gold = sin((bg.x + bg.y) * PI + time * 0.3) * 0.5 + 0.5;
  vec3 goldColor = mix(
    vec3(1.0, 0.84, 0.0),   // gold
    vec3(1.0, 0.65, 0.0),   // orange
    gold
  );
  vec3 layer1 = goldColor * 0.5;

  // [레이어 2] 글리터 레이어 A (좌→우 이동).
  float g1 = hash(floor(uv * 150.0 + vec2(time * 5.0, 0.0)));
  g1 = pow(g1, 12.0);
  vec3 layer2 = vec3(1.0, 0.95, 0.7) * g1 * 0.9;

  // [레이어 3] 글리터 레이어 B (우→좌 이동, 반대 방향).
  float g2 = hash(floor(uv * 180.0 + vec2(-time * 4.0, time * 2.0)));
  g2 = pow(g2, 14.0);
  vec3 layer3 = vec3(1.0, 0.9, 0.5) * g2 * 0.8;

  // [레이어 4] FBM 골드 텍스처.
  float foil = fbm(uv * 10.0 + time * 0.08);
  vec3 layer4 = mix(goldColor, vec3(1.0, 1.0, 0.85), foil) * foil * 0.3;

  vec3 result = layer1;
  result = blendOverlay(result, layer2);
  result = blendColorDodge(result, layer3);
  result = blendSoftLight(result, layer4);

  return result;
}

// ─── 커서 글로우 (모든 래리티 공통) ───────────────────────────
vec3 cursorGlow(vec2 uv, vec2 pointer) {
  float dist = distance(uv, pointer);
  float glow = smoothstep(0.6, 0.0, dist);
  vec3 glowColor = spectrum(pointer.x + 0.2);
  return glowColor * glow * 0.4;
}

// ─── Main ────────────────────────────────────────────────────
void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uResolution;

  // 카드 비율 보정 (UV를 정사각형 공간으로 변환).
  vec2 aspectUv = uv;
  if (uCardAspect > 1.0) {
    aspectUv.y /= uCardAspect;
  } else {
    aspectUv.x *= uCardAspect;
  }

  // 마우스 진입 시 페이드.
  if (uOpacity <= 0.001) {
    fragColor = vec4(0.0);
    return;
  }

  int rarity = int(uRarity);
  vec3 holo = vec3(0.0);

  // 래리티별 홀로 패턴 생성.
  if (rarity == 1) {
    holo = regularHolo(aspectUv, uPointer, uTime);
  } else if (rarity == 2) {
    holo = reverseHolo(aspectUv, uPointer, uTime);
  } else if (rarity == 3) {
    holo = illustrationRare(aspectUv, uPointer, uTime);
  } else if (rarity == 4) {
    holo = hyperRare(aspectUv, uPointer, uTime);
  }

  // 커서 글로우 오버레이 (softLight).
  holo = blendSoftLight(holo, cursorGlow(uv, uPointer));

  // 효과 강도 적용 (uniform으로 런타임 조정).
  holo *= uIntensity;

  // gamma 보정으로 중간톤 강조.
  holo = pow(max(holo, 0.0), vec3(0.85));

  // 카드 모서리 페이드 (둥근 모서리 영역에서 홀로 약화).
  float edgeDist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
  float edgeFade = smoothstep(0.0, 0.03, edgeDist);

  // alpha: brightness 비례 제거. colorDodge 블렌드 모드가
  // 어두운 색은 자동으로 무시하므로 alpha는 단순 페이드만 담당.
  float alpha = uOpacity * edgeFade;

  // premultiplied alpha 출력.
  fragColor = vec4(holo * alpha, alpha);
}
