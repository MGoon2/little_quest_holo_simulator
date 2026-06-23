import 'dart:io';
import 'dart:ui' as ui;

import 'package:croppy/croppy.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 사진 선택 + 크롭 + 앱 디렉토리 영구 보관을 담당한다.
///
/// image_picker 로 갤러리/카메라에서 선택 → croppy 로 카드 비율(5:7)에
/// 맞춰 크롭 → 앱 전용 디렉토리에 복사하여 영구 경로를 반환한다.
///
/// croppy 는 Flutter 로 구현된 크로스플랫폼 크로퍼로 macOS/iOS/Android/Web
/// 모두 지원한다 (image_cropper 는 macOS 미지원).
class PhotoService {
  PhotoService();

  final _picker = ImagePicker();

  /// 갤러리에서 선택하여 크롭된 영구 파일 경로를 반환.
  /// 실패/취소 시 null.
  Future<String?> pickAndCropFromGallery(BuildContext context) async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return null;
    if (!context.mounted) return null;
    return _cropAndPersist(context, xfile.path);
  }

  /// 카메라로 촬영하여 크롭된 영구 파일 경로를 반환.
  Future<String?> takeAndCropFromCamera(BuildContext context) async {
    final xfile = await _picker.pickImage(source: ImageSource.camera);
    if (xfile == null) return null;
    if (!context.mounted) return null;
    return _cropAndPersist(context, xfile.path);
  }

  Future<String?> _cropAndPersist(BuildContext context, String sourcePath) async {
    final result = await showMaterialImageCropper(
      context,
      imageProvider: FileImage(File(sourcePath)),
      allowedAspectRatios: const [
        CropAspectRatio(width: 5, height: 7),
      ],
      enabledTransformations: const [
        Transformation.panAndScale,
        Transformation.resize,
      ],
    );
    if (result == null) return null;

    // croppy 결과(ui.Image)를 PNG 바이트로 추출하여 앱 디렉토리에 저장.
    final byteData = await result.uiImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) return null;
    final data = byteData.buffer.asUint8List();

    final dir = await getApplicationDocumentsDirectory();
    final cardsDir = Directory(p.join(dir.path, 'card_photos'));
    if (!await cardsDir.exists()) {
      await cardsDir.create(recursive: true);
    }
    final dest = p.join(
      cardsDir.path,
      'card_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await File(dest).writeAsBytes(data);
    return dest;
  }

  /// 홀로 텍스처 이미지를 갤러리에서 선택.
  /// 크롭 없이 원본 그대로 저장 — 렌더링 시 카드에 맞춰 자동 조절됨.
  Future<String?> pickHoloFromGallery(BuildContext context) async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return null;
    if (!context.mounted) return null;
    return _persistHoloImage(xfile.path);
  }

  Future<String?> _persistHoloImage(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final holoDir = Directory(p.join(dir.path, 'holo_sheets'));
    if (!await holoDir.exists()) {
      await holoDir.create(recursive: true);
    }
    final dest = p.join(
      holoDir.path,
      'holo_${DateTime.now().microsecondsSinceEpoch}${p.extension(sourcePath)}',
    );
    await File(sourcePath).copy(dest);
    return dest;
  }
}
