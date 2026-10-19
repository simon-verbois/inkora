import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/images/image_enhancement.dart';
import '../../features/settings/application/ui_preferences_provider.dart';

final imageEnhancementProgramsProvider = FutureProvider(
  (ref) async => (
    await ui.FragmentProgram.fromAsset('assets/shaders/image_enhancement.frag'),
    ui.ImageFilter.isShaderFilterSupported
        ? await ui.FragmentProgram.fromAsset(
            'assets/shaders/surface_enhancement.frag',
          )
        : null,
  ),
);

/// Load two tiny programs when display enhancement is enabled. Images observe one inherited value,
/// not separate preference/asset futures; MaterialApp and themes stay untouched.
class ImageEnhancementHost extends ConsumerWidget {
  const ImageEnhancementHost({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(
      uiPreferencesProvider.select(
        (state) =>
            state.asData?.value.imageEnhancement ?? ImageEnhancement.balanced,
      ),
    );
    final programs = level == ImageEnhancement.off
        ? null
        : ref.watch(imageEnhancementProgramsProvider).asData?.value;
    return ImageEnhancementScope(
      level: level,
      program: programs?.$1,
      surfaceProgram: programs?.$2,
      child: child,
    );
  }
}

class ImageEnhancementScope extends InheritedWidget {
  const ImageEnhancementScope({
    required this.level,
    required super.child,
    this.program,
    this.surfaceProgram,
    super.key,
  });
  final ImageEnhancement level;
  final ui.FragmentProgram? program, surfaceProgram;

  static ImageEnhancementScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ImageEnhancementScope>();
  static ImageEnhancement levelOf(BuildContext context) =>
      maybeOf(context)?.level ?? ImageEnhancement.off;

  @override
  bool updateShouldNotify(ImageEnhancementScope oldWidget) =>
      level != oldWidget.level ||
      program != oldWidget.program ||
      surfaceProgram != oldWidget.surfaceProgram;
}

/// Paint the already decoded image directly. No second image, bitmap cache,
/// saveLayer, readback or network request is introduced for pages or covers.
class EnhancedRawImage extends StatefulWidget {
  const EnhancedRawImage({
    required this.raw,
    this.fallback,
    this.colorFilter,
    super.key,
  });
  final RawImage raw;
  final Widget? fallback;
  final ColorFilter? colorFilter;

  @override
  State<EnhancedRawImage> createState() => _EnhancedRawImageState();
}

class _EnhancedRawImageState extends State<EnhancedRawImage> {
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  ui.Image? _image;
  FilterQuality? _sampling;
  double _strength = 0;

  void _clear() {
    _shader?.dispose();
    _shader = null;
    _program = null;
    _image = null;
    _sampling = null;
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ImageEnhancementScope.maybeOf(context);
    final raw = widget.raw;
    final image = raw.image;
    final strength = scope?.level.strength ?? 0;
    // Preserve unusual RawImage paint semantics rather than silently changing
    // them. The application's page/cover images use the supported normal path.
    if (strength == 0 ||
        scope?.program == null ||
        image == null ||
        raw.color != null ||
        raw.opacity != null ||
        raw.centerSlice != null ||
        raw.repeat != ImageRepeat.noRepeat ||
        raw.matchTextDirection) {
      _clear();
      return widget.fallback ?? raw;
    }
    if (_program != scope!.program) {
      _clear();
      _program = scope.program;
      _shader = _program!.fragmentShader();
    }
    if (_image != image || _sampling != raw.filterQuality) {
      _shader!.setImageSampler(0, image, filterQuality: raw.filterQuality);
      _image = image;
      _sampling = raw.filterQuality;
    }
    _strength = strength;
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(
        width: raw.width,
        height: raw.height,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.constrainSizeAndAttemptToPreserveAspectRatio(
            Size(image.width / raw.scale, image.height / raw.scale),
          );
          return SizedBox.fromSize(
            size: size,
            child: CustomPaint(
              painter: _EnhancedPainter(
                raw,
                _shader!,
                _strength,
                widget.colorFilter,
                raw.alignment.resolve(Directionality.of(context)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EnhancedPainter extends CustomPainter {
  _EnhancedPainter(
    this.raw,
    this.shader,
    this.strength,
    this.filter,
    this.alignment,
  );
  final RawImage raw;
  final ui.FragmentShader shader;
  final double strength;
  final ColorFilter? filter;
  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    final image = raw.image!;
    final actual = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(
      raw.fit ?? BoxFit.scaleDown,
      actual / raw.scale,
      size,
    );
    final source = alignment.inscribe(
      fitted.source * raw.scale,
      Offset.zero & actual,
    );
    final target = alignment.inscribe(fitted.destination, Offset.zero & size);
    if (target.isEmpty) return;
    final values = [
      target.width,
      target.height,
      actual.width,
      actual.height,
      source.left,
      source.top,
      source.width,
      source.height,
      strength,
    ];
    for (var index = 0; index < values.length; index++) {
      shader.setFloat(index, values[index]);
    }
    final paint = Paint()
      ..shader = shader
      ..colorFilter = filter
      ..invertColors = raw.invertColors;
    canvas.save();
    canvas.translate(target.left, target.top);
    canvas.drawRect(Offset.zero & target.size, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EnhancedPainter oldDelegate) =>
      oldDelegate.raw.image != raw.image ||
      oldDelegate.shader != shader ||
      oldDelegate.strength != strength ||
      oldDelegate.filter != filter ||
      oldDelegate.raw.fit != raw.fit ||
      oldDelegate.raw.scale != raw.scale ||
      oldDelegate.raw.filterQuality != raw.filterQuality ||
      oldDelegate.raw.invertColors != raw.invertColors ||
      oldDelegate.alignment != alignment;
}

/// A single bounded PDF viewport filter. Unsupported backends keep the original
/// native-quality PDF surface; no bitmap capture or page cache is created here.
class EnhancedDocumentSurface extends StatefulWidget {
  const EnhancedDocumentSurface({required this.child, super.key});
  final Widget child;
  @override
  State<EnhancedDocumentSurface> createState() =>
      _EnhancedDocumentSurfaceState();
}

class _EnhancedDocumentSurfaceState extends State<EnhancedDocumentSurface> {
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  ui.ImageFilter? _filter;
  double _strength = 0;

  void _clear() {
    _filter = null;
    _shader?.dispose();
    _shader = null;
    _program = null;
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ImageEnhancementScope.maybeOf(context);
    final strength = scope?.level.strength ?? 0;
    if (strength == 0 ||
        scope?.surfaceProgram == null ||
        !ui.ImageFilter.isShaderFilterSupported) {
      _clear();
      return widget.child;
    }
    if (_program != scope!.surfaceProgram || _strength != strength) {
      _clear();
      _program = scope.surfaceProgram;
      _shader = _program!.fragmentShader()..setFloat(2, strength);
      _filter = ui.ImageFilter.shader(_shader!);
      _strength = strength;
    }
    return ImageFiltered(imageFilter: _filter!, child: widget.child);
  }
}
