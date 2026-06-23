import 'dart:io';

import 'package:flutter/material.dart';

import '../models/card_data.dart';
import '../services/photo_service.dart';

/// 카드 생성/편집 다이얼로그.
///
/// 1. 사진 선택 (갤러리/카메라)
/// 2. 타이틀 / 서브타이틀 입력
/// 3. 래리티 선택
/// 4. (선택) 메모
class CardEditorDialog extends StatefulWidget {
  const CardEditorDialog({super.key, this.initial});

  final CardData? initial;

  @override
  State<CardEditorDialog> createState() => _CardEditorDialogState();
}

class _CardEditorDialogState extends State<CardEditorDialog> {
  final _photoService = PhotoService();
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  String? _imagePath;
  String? _holoImagePath;
  Rarity _rarity = Rarity.regularHolo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final c = widget.initial!;
      _titleCtrl.text = c.title;
      _subtitleCtrl.text = c.subtitle;
      _memoCtrl.text = c.memo;
      _rarity = c.rarity;
      _imagePath = c.imagePath;
      _holoImagePath = c.holoImagePath;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final path = await _photoService.pickAndCropFromGallery(context);
    if (path != null) setState(() => _imagePath = path);
  }

  Future<void> _pickFromCamera() async {
    final path = await _photoService.takeAndCropFromCamera(context);
    if (path != null) setState(() => _imagePath = path);
  }

  Future<void> _pickHoloImage() async {
    final path = await _photoService.pickAndCropHoloFromGallery(context);
    if (path != null) setState(() => _holoImagePath = path);
  }

  void _clearHoloImage() {
    setState(() => _holoImagePath = null);
  }

  Future<void> _save() async {
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 먼저 선택해주세요.')),
      );
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('타이틀을 입력해주세요.')),
      );
      return;
    }
    setState(() => _saving = true);
    final card = CardData(
      id: widget.initial?.id ??
          'card_${DateTime.now().microsecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      subtitle: _subtitleCtrl.text.trim(),
      rarity: _rarity,
      imagePath: _imagePath!,
      holoImagePath: _holoImagePath,
      memo: _memoCtrl.text.trim(),
    );
    if (mounted) Navigator.of(context).pop(card);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1F1F1F),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initial == null ? '새 카드 만들기' : '카드 편집',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _PhotoPicker(
                      imagePath: _imagePath,
                      onGallery: _pickFromGallery,
                      onCamera: _pickFromCamera,
                    ),
                    const SizedBox(height: 20),
                    _TextField(
                      label: '타이틀',
                      controller: _titleCtrl,
                      hint: '예: 정원의 고양이',
                    ),
                    const SizedBox(height: 12),
                    _TextField(
                      label: '서브타이틀',
                      controller: _subtitleCtrl,
                      hint: '예: 2026.06.22',
                    ),
                    const SizedBox(height: 12),
                    _RarityPicker(
                      value: _rarity,
                      onChanged: (r) => setState(() => _rarity = r),
                    ),
                    const SizedBox(height: 16),
                    _HoloImagePicker(
                      holoImagePath: _holoImagePath,
                      onPick: _pickHoloImage,
                      onClear: _clearHoloImage,
                    ),
                    const SizedBox(height: 12),
                    _TextField(
                      label: '메모 (선택)',
                      controller: _memoCtrl,
                      hint: '카드 하단에 표시될 짧은 메모',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '저장 중…' : '저장'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.imagePath,
    required this.onGallery,
    required this.onCamera,
  });

  final String? imagePath;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final aspect = 2.5 / 3.5;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = w / aspect;
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(imagePath!), fit: BoxFit.cover),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Center(
                    child: Icon(Icons.image_outlined,
                        size: 60, color: Colors.white24),
                  ),
                ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Row(
                  children: [
                    _PhotoButton(
                      icon: Icons.photo_outlined,
                      label: '갤러리',
                      onTap: onGallery,
                    ),
                    const SizedBox(width: 8),
                    _PhotoButton(
                      icon: Icons.camera_alt_outlined,
                      label: '카메라',
                      onTap: onCamera,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFA855F7)),
        ),
      ),
    );
  }
}

class _RarityPicker extends StatelessWidget {
  const _RarityPicker({required this.value, required this.onChanged});

  final Rarity value;
  final ValueChanged<Rarity> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Rarity.values.map((r) {
        final selected = r == value;
        return ChoiceChip(
          label: Text(r.label),
          selected: selected,
          onSelected: (_) => onChanged(r),
          selectedColor: Color(r.frameColor),
          labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.white70,
          ),
          backgroundColor: const Color(0xFF2A2A2A),
        );
      }).toList(),
    );
  }
}

/// 홀로 텍스처 이미지 선택기.
///
/// 사용자가 직접 홀로 시트 이미지를 선택할 수 있다.
/// 선택하지 않으면 래리티별 셰이더 홀로가 사용된다.
class _HoloImagePicker extends StatelessWidget {
  const _HoloImagePicker({
    required this.holoImagePath,
    required this.onPick,
    required this.onClear,
  });

  final String? holoImagePath;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 홀로 이미지 썸네일.
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
            image: holoImagePath != null
                ? DecorationImage(
                    image: FileImage(File(holoImagePath!)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: holoImagePath == null
              ? const Icon(Icons.texture, color: Colors.white24, size: 28)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '홀로 텍스처 (선택)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                holoImagePath != null
                    ? '사용자 홀로 이미지 적용됨'
                    : '미선택 시 래리티별 셰이더 홀로 사용',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (holoImagePath != null)
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: Colors.white54,
            onPressed: onClear,
            tooltip: '홀로 이미지 제거',
          ),
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: Text(holoImagePath != null ? '변경' : '선택'),
        ),
      ],
    );
  }
}
