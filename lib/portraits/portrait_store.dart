import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'portrait_pipeline.dart';

/// One imported portrait on disk: cutout_both.png, portrait.jpg, shading*.png, split.txt, thumb.jpg.
class Portrait {
  Portrait(this.dir);
  final Directory dir;

  String get id => dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
  File get thumb => File('${dir.path}/thumb.jpg');

  /// Starting waist line (fraction of image height) guessed at import time.
  Future<double> splitFraction() async {
    final f = File('${dir.path}/split.txt');
    return await f.exists() ? double.tryParse(await f.readAsString()) ?? 0.6 : 0.6;
  }

  Future<ui.Image> image(String name) async {
    final bytes = await File('${dir.path}/$name').readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }
}

/// Segments a photo on device and keeps the generated assets in app documents.
class PortraitStore {
  Interpreter? _interpreter;

  Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/portraits').create(recursive: true);
  }

  Future<List<Portrait>> list() async {
    final root = await _root();
    final dirs = root.listSync().whereType<Directory>().where((d) => File('${d.path}/thumb.jpg').existsSync()).toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return [for (final d in dirs) Portrait(d)];
  }

  Future<void> delete(Portrait p) => p.dir.delete(recursive: true);

  Future<Interpreter> _model() async =>
      _interpreter ??= await Interpreter.fromAsset('assets/model/selfie_multiclass_256x256.tflite');

  /// Throws [NoClothesFound] or a [StateError] with a user-readable message.
  Future<Portrait> import(String photoPath) async {
    final prepared = await preparePhoto(await File(photoPath).readAsBytes());
    final interpreter = await _model();
    final input = prepared.modelInput.reshape([1, modelSize, modelSize, 3]);
    final output = List.generate(1, (_) => List.generate(modelSize, (_) => List.generate(modelSize, (_) => List.filled(6, 0.0))));
    interpreter.run(input, output);
    final flat = Float32List(modelSize * modelSize * 6);
    var i = 0;
    for (final row in output[0]) {
      for (final px in row) {
        for (final v in px) {
          flat[i++] = v;
        }
      }
    }
    final assets = await buildPortraitAssets(BuildArgs(prepared.rgb, prepared.width, prepared.height, clothesProbability(flat)));
    final dir = Directory('${(await _root()).path}/${DateTime.now().millisecondsSinceEpoch}');
    await dir.create();
    for (final e in assets.entries) {
      await File('${dir.path}/${e.key}').writeAsBytes(e.value);
    }
    return Portrait(dir);
  }
}

/// The bundled spike photo, loaded the same way as an imported portrait.
Future<ui.Image> bundledImage(String name) async {
  final data = await rootBundle.load('assets/spike/$name');
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  return (await codec.getNextFrame()).image;
}
