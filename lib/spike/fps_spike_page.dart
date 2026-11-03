import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../portraits/portrait_pipeline.dart';
import '../portraits/portrait_store.dart';

/// M0 spike 2: live fabric (camera or stock swatch) behind a garment cutout, two ways, with an fps readout.
/// A: Stack (CameraPreview texture or tiled swatch, multiply shading, cutout PNG).
/// B: imageStream -> ui.Image -> FragmentShader (one pass).
enum SpikeMode { stack, shader }

/// Which part of the garment shows the fabric.
enum Region { both, torso, legs }

const _fabrics = ['denim', 'houndstooth', 'tartan', 'breton', 'gingham', 'camo', 'leopard', 'floral', 'corduroy', 'herringbone', 'polka'];
const _bundledSplit = 0.692;

class FpsSpikePage extends StatefulWidget {
  const FpsSpikePage({super.key});

  @override
  State<FpsSpikePage> createState() => _FpsSpikePageState();
}

class _FpsSpikePageState extends State<FpsSpikePage> {
  CameraController? _cam;
  String? _error;
  SpikeMode _mode = SpikeMode.stack;
  double _strength = 0.8;
  double _detail = 1.0;
  bool _panel = true;

  Region _region = Region.both;
  double _split = _bundledSplit; // waist line, fraction of portrait height
  bool _draggingSplit = false;
  ui.Image? _cut, _portraitImg, _shade, _shadeMul;

  String? _fabric; // null = live camera
  final Map<String, ui.Image> _fabricImages = {};
  double _tile = 3; // swatch repeats across the screen width

  ui.FragmentProgram? _program;
  final ValueNotifier<ui.Image?> _frame = ValueNotifier(null);
  bool _decoding = false;
  final _store = PortraitStore();
  Portrait? _portrait; // null = bundled spike photo
  bool _importing = false;
  String _frameInfo = '';

  // metrics
  int _rasterFrames = 0, _camFrames = 0, _decodedFrames = 0;
  double _rasterMsSum = 0, _decodeMsSum = 0;
  Timer? _tick;
  String _stats = '…';

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _flush());
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
      final c = CameraController(
        back,
        ResolutionPreset.high, // 1280x720
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      await c.initialize();
      final results = await _loadSet(bundledImage);
      _program = await ui.FragmentProgram.fromAsset('shaders/composite.frag');
      if (!mounted) return;
      setState(() {
        _cam = c;
        _applySet(results);
      });
      await _applyMode();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<List<ui.Image>> _loadSet(Future<ui.Image> Function(String) load) => Future.wait([
        load('cutout_both.png'),
        load('portrait.jpg'),
        load('shading.png'),
        load('shading_mul.png'),
      ]);

  void _applySet(List<ui.Image> r) {
    final old = [?_cut, ?_portraitImg, ?_shade, ?_shadeMul];
    _cut = r[0];
    _portraitImg = r[1];
    _shade = r[2];
    _shadeMul = r[3];
    // dispose after the next frame so a painter still holding the old image does not trip
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final i in old) {
        i.dispose();
      }
    });
  }

  Future<void> _use(Portrait? p) async {
    final set = await _loadSet(p == null ? bundledImage : p.image);
    final split = p == null ? _bundledSplit : await p.splitFraction();
    if (!mounted) return;
    setState(() {
      _portrait = p;
      _split = split;
      _applySet(set);
    });
  }

  Future<void> _pickFabric(String? name) async {
    if (name != null && !_fabricImages.containsKey(name)) {
      final data = await rootBundle.load('assets/fabrics/$name.jpg');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _fabricImages[name] = (await codec.getNextFrame()).image;
    }
    if (!mounted) return;
    setState(() => _fabric = name);
    await _applyMode();
  }

  Future<void> _addPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _importing = true);
    try {
      final p = await _store.import(file.path);
      await _use(p);
    } on NoClothesFound catch (e) {
      _toast('$e');
    } catch (e) {
      _toast('Import failed: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _toast(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _openPhotos() async {
    final saved = await _store.list();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Your photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Pick a photo of one person with the garment fully visible. Head to feet works best if you want to change the top and trousers separately.\n\n'
              'Torso: top only. Needs a standing shot showing hips or lower.\n'
              'Legs: trousers or skirt only. Needs knees or feet in frame.\n'
              'Both: the whole garment. Use this for upper-body crops, dresses and jumpsuits.\n\n'
              'Torso and Legs split at a waist line you can drag. It starts at a guess, so check it on your photo.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _photoTile(ctx, null, Image.asset('assets/spike/portrait.jpg', fit: BoxFit.cover, cacheWidth: 200), _portrait == null),
                for (final p in saved) _photoTile(ctx, p, Image.file(p.thumb, fit: BoxFit.cover), _portrait?.id == p.id),
              ]),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _addPhoto();
              },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add photo'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _photoTile(BuildContext ctx, Portrait? p, Widget child, bool selected) => GestureDetector(
        onTap: () {
          Navigator.pop(ctx);
          _use(p);
        },
        onLongPress: p == null
            ? null
            : () async {
                Navigator.pop(ctx);
                await _store.delete(p);
                if (_portrait?.id == p.id) await _use(null);
              },
        child: Container(
          width: 72,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? const Color(0xFFD7F94A) : const Color(0xFF2C2B28), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      );

  /// The camera stream is only needed for Shader mode on live camera.
  Future<void> _applyMode() async {
    final c = _cam;
    if (c == null) return;
    if (c.value.isStreamingImages) await c.stopImageStream();
    if (_mode == SpikeMode.shader && _fabric == null) {
      await c.startImageStream(_onCameraImage);
    }
    _resetStats();
  }

  void _onCameraImage(CameraImage img) {
    _camFrames++;
    if (_decoding) return; // drop frames while the previous one is still uploading
    _decoding = true;
    final sw = Stopwatch()..start();
    final plane = img.planes.first;
    _frameInfo = '${img.width}x${img.height} bpr ${plane.bytesPerRow}';
    var bytes = plane.bytes;
    if (plane.bytesPerRow != img.width * 4) {
      // drop row padding so the texture width matches the real frame width
      final tight = Uint8List(img.width * 4 * img.height);
      for (var y = 0; y < img.height; y++) {
        tight.setRange(y * img.width * 4, (y + 1) * img.width * 4, bytes, y * plane.bytesPerRow);
      }
      bytes = tight;
    }
    ui.decodeImageFromPixels(
      bytes,
      img.width,
      img.height,
      ui.PixelFormat.bgra8888,
      (image) {
        _decodeMsSum += sw.elapsedMicroseconds / 1000;
        _decodedFrames++;
        _frame.value?.dispose();
        _frame.value = image;
        _decoding = false;
      },
    );
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _rasterFrames++;
      _rasterMsSum += t.rasterDuration.inMicroseconds / 1000;
    }
  }

  void _resetStats() {
    _rasterFrames = _camFrames = _decodedFrames = 0;
    _rasterMsSum = _decodeMsSum = 0;
  }

  void _flush() {
    if (!mounted) return;
    final r = _rasterFrames == 0 ? 0 : _rasterMsSum / _rasterFrames;
    final d = _decodedFrames == 0 ? 0 : _decodeMsSum / _decodedFrames;
    final txt = _mode == SpikeMode.stack
        ? 'STACK  ui $_rasterFrames fps  raster ${r.toStringAsFixed(1)} ms'
        : 'SHADER  ui $_rasterFrames fps  cam $_camFrames in / $_decodedFrames used  raster ${r.toStringAsFixed(1)} ms  upload ${d.toStringAsFixed(1)} ms  $_frameInfo';
    debugPrint('[spike2] $txt');
    if (_panel) setState(() => _stats = txt);
    _rasterFrames = _camFrames = _decodedFrames = 0;
    _rasterMsSum = _decodeMsSum = 0;
  }

  @override
  void dispose() {
    _tick?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _cam;
    if (_error != null) return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!))));
    if (c == null || _cut == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final size = box.biggest;
        return Stack(fit: StackFit.expand, children: [
          _mode == SpikeMode.stack ? _stackView(c) : _shaderView(c, size),
          if (_panel && _draggingSplit && _region != Region.both)
            Positioned(
              left: 0,
              right: 0,
              top: _splitScreenY(size) - 1,
              child: Container(height: 2, color: const Color(0xFFD7F94A)),
            ),
          if (_panel)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8, 8, 56, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xCC0F0F0E), borderRadius: BorderRadius.circular(12)),
                  child: Text(_stats, style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filledTonal(
                  tooltip: _panel ? 'Hide controls' : 'Show controls',
                  style: IconButton.styleFrom(backgroundColor: const Color(0xAA1C1B19)),
                  onPressed: () => setState(() => _panel = !_panel),
                  icon: Icon(_panel ? Icons.visibility_off_outlined : Icons.tune),
                ),
              ),
            ),
          ),
          if (_panel) _controls(size),
        ]);
      }),
    );
  }

  Widget _controls(Size size) => Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            constraints: BoxConstraints(maxHeight: size.height * 0.55),
            decoration: BoxDecoration(color: const Color(0xDD1C1B19), borderRadius: BorderRadius.circular(22)),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  height: 52,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    _fabricChip(null),
                    for (final f in _fabrics) _fabricChip(f),
                  ]),
                ),
                const SizedBox(height: 8),
                Center(
                  child: SegmentedButton<SpikeMode>(
                    segments: const [
                      ButtonSegment(value: SpikeMode.stack, label: Text('A  Stack')),
                      ButtonSegment(value: SpikeMode.shader, label: Text('B  Shader')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) {
                      setState(() => _mode = s.first);
                      _applyMode();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: SegmentedButton<Region>(
                    segments: const [
                      ButtonSegment(value: Region.torso, label: Text('Torso')),
                      ButtonSegment(value: Region.legs, label: Text('Legs')),
                      ButtonSegment(value: Region.both, label: Text('Both')),
                    ],
                    selected: {_region},
                    onSelectionChanged: (s) => setState(() => _region = s.first),
                  ),
                ),
                Text(
                  switch (_region) {
                    Region.torso => 'Top only. Drag the waist line to where the top ends.',
                    Region.legs => 'Trousers/skirt only. Drag the waist line to where they start.',
                    Region.both => 'Whole garment. Best for upper-body crops, dresses, jumpsuits.',
                  },
                  style: const TextStyle(fontSize: 11, color: Color(0xFFA19D95)),
                ),
                if (_region != Region.both)
                  _slider('Waist', _split, (v) => setState(() => _split = v),
                      min: 0.15, max: 0.95, onStart: () => setState(() => _draggingSplit = true), onEnd: () => setState(() => _draggingSplit = false)),
                _slider('Shading', _strength, (v) => setState(() => _strength = v)),
                if (_mode == SpikeMode.shader) _slider('Detail', _detail, (v) => setState(() => _detail = v)),
                if (_fabric != null) _slider('Pattern size', 11 - _tile, (v) => setState(() => _tile = 11 - v), min: 1, max: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _importing ? null : _openPhotos,
                    icon: _importing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(_importing ? 'Cutting out…' : 'Change photo'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _slider(String label, double value, ValueChanged<double> onChanged,
          {double min = 0, double max = 1, VoidCallback? onStart, VoidCallback? onEnd}) =>
      Row(children: [
        SizedBox(width: 84, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeStart: onStart == null ? null : (_) => onStart(),
            onChangeEnd: onEnd == null ? null : (_) => onEnd(),
          ),
        ),
      ]);

  Widget _fabricChip(String? name) {
    final selected = _fabric == name;
    return GestureDetector(
      onTap: () => _pickFabric(name),
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2C2B28),
          border: Border.all(color: selected ? const Color(0xFFD7F94A) : const Color(0xFF2C2B28), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: name == null
            ? const Icon(Icons.photo_camera_outlined, size: 20)
            : Image.asset('assets/fabrics/$name.jpg', fit: BoxFit.cover, cacheWidth: 96),
      ),
    );
  }

  /// Fraction of `image` visible when cover-fitted into a box of aspect `screen` (w/h).
  Offset _cover(double imageAspect, double screenAspect) =>
      screenAspect > imageAspect ? Offset(1, imageAspect / screenAspect) : Offset(screenAspect / imageAspect, 1);

  /// Screen y of the waist line for the cover-fitted portrait.
  double _splitScreenY(Size size) {
    final ia = _cut!.width / _cut!.height;
    final fy = _cover(ia, size.width / size.height).dy;
    return ((_split - (1 - fy) / 2) / fy) * size.height;
  }

  Widget _stackView(CameraController c) {
    final p = c.value.previewSize!; // landscape; upright it is (height x width)
    final swatch = _fabric == null ? null : _fabricImages[_fabric];
    return Stack(fit: StackFit.expand, children: [
      if (swatch == null)
        ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(width: p.height, height: p.width, child: CameraPreview(c)),
          ),
        )
      else
        CustomPaint(painter: _TilePainter(swatch, _tile)),
      // multiply the garment luminance over the fabric
      CustomPaint(painter: _MultiplyPainter(_shadeMul!, _strength)),
      RawImage(image: _cut, fit: BoxFit.cover),
      if (_region != Region.both) CustomPaint(painter: _ExcludePainter(_portraitImg!, _split, _region)),
    ]);
  }

  Widget _shaderView(CameraController c, Size size) {
    final p = c.value.previewSize!;
    final sa = size.width / size.height;
    final swatch = _fabric == null ? null : _fabricImages[_fabric];
    return ValueListenableBuilder<ui.Image?>(
      valueListenable: _frame,
      builder: (_, frame, _) {
        final fabricImage = swatch ?? frame;
        return fabricImage == null
            ? const SizedBox.expand()
            : CustomPaint(
                size: Size.infinite,
                painter: _ShaderPainter(
                  program: _program!,
                  fabric: fabricImage,
                  tile: swatch == null ? 0 : _tile,
                  shade: _shade!,
                  shadeSharp: _shadeMul!,
                  portrait: _portraitImg!,
                  detail: _detail,
                  split: _split,
                  region: _region.index,
                  cut: _cut!,
                  strength: _strength,
                  camScale: _cover(p.height / p.width, sa),
                  cutScale: _cover(_cut!.width / _cut!.height, sa),
                ),
              );
      },
    );
  }
}

/// Draws a cover-fit crop of `image` into `size`, returns the crop and the cover fractions.
Rect _coverCrop(ui.Image image, Size size) {
  final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  final sa = size.width / size.height, ia = image.width / image.height;
  final f = sa > ia ? Size(1, ia / sa) : Size(sa / ia, 1);
  return Rect.fromCenter(center: src.center, width: src.width * f.width, height: src.height * f.height);
}

class _MultiplyPainter extends CustomPainter {
  _MultiplyPainter(this.image, this.strength);
  final ui.Image image;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      _coverCrop(image, size),
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.multiply
        ..color = Color.fromRGBO(255, 255, 255, strength),
    );
  }

  @override
  bool shouldRepaint(_MultiplyPainter old) => old.strength != strength || old.image != image;
}

/// Opaque original portrait over the part of the garment that keeps its own fabric.
class _ExcludePainter extends CustomPainter {
  _ExcludePainter(this.image, this.split, this.region);
  final ui.Image image;
  final double split;
  final Region region;

  @override
  void paint(Canvas canvas, Size size) {
    final crop = _coverCrop(image, size);
    final splitY = (split * image.height - crop.top) / crop.height * size.height;
    final keepBelowOnly = region == Region.torso; // torso takes fabric above the line, so show the original below it
    final area = keepBelowOnly ? Rect.fromLTRB(0, splitY, size.width, size.height) : Rect.fromLTRB(0, 0, size.width, splitY);
    canvas.save();
    canvas.clipRect(area);
    canvas.drawImageRect(image, crop, Offset.zero & size, Paint());
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ExcludePainter old) => old.split != split || old.region != region || old.image != image;
}

/// Tiles a fabric swatch `tile` times across the width.
class _TilePainter extends CustomPainter {
  _TilePainter(this.image, this.tile);
  final ui.Image image;
  final double tile;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / tile / image.width;
    final shader = ImageShader(image, TileMode.repeated, TileMode.repeated, (Matrix4.identity()..scaleByDouble(s, s, 1, 1)).storage,
        filterQuality: FilterQuality.medium);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_TilePainter old) => old.image != image || old.tile != tile;
}

class _ShaderPainter extends CustomPainter {
  _ShaderPainter({
    required this.program,
    required this.fabric,
    required this.tile,
    required this.shade,
    required this.shadeSharp,
    required this.portrait,
    required this.detail,
    required this.split,
    required this.region,
    required this.cut,
    required this.strength,
    required this.camScale,
    required this.cutScale,
  });
  final ui.FragmentProgram program;
  final ui.Image fabric, shade, shadeSharp, portrait, cut;
  final double strength, detail, tile, split;
  final int region;
  final Offset camScale, cutScale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, strength)
      ..setFloat(3, camScale.dx)
      ..setFloat(4, camScale.dy)
      ..setFloat(5, cutScale.dx)
      ..setFloat(6, cutScale.dy)
      ..setFloat(7, detail)
      ..setFloat(8, tile)
      ..setFloat(9, split)
      ..setFloat(10, region.toDouble())
      ..setImageSampler(0, fabric)
      ..setImageSampler(1, shade)
      ..setImageSampler(2, cut)
      ..setImageSampler(3, shadeSharp)
      ..setImageSampler(4, portrait);
    canvas.drawRect(Offset.zero & size, Paint()..shader = s);
  }

  @override
  bool shouldRepaint(_ShaderPainter old) => true;
}
