import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Width every portrait is normalised to (matches the spike-1/2 assets).
const portraitWidth = 750;
const modelSize = 256;
const _clothesClass = 4;
const _classes = 6;
const _waistFraction = 0.47;

class NoClothesFound implements Exception {
  @override
  String toString() => 'No clothing found. Try a photo with one person, upper body in frame.';
}

/// Decoded photo plus the model input, produced off the UI isolate.
class PreparedPhoto {
  PreparedPhoto(this.rgb, this.width, this.height, this.modelInput);
  final Uint8List rgb; // width*height*3
  final int width, height;
  final Float32List modelInput; // 256*256*3, 0..1
}

Future<PreparedPhoto> preparePhoto(Uint8List fileBytes) => Isolate.run(() => _prepareBytes(fileBytes));

PreparedPhoto _prepareBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw StateError('Could not read that image (HEIC? try a JPG or PNG).');
  final upright = img.bakeOrientation(decoded);
  final photo = img.copyResize(upright, width: portraitWidth, interpolation: img.Interpolation.average);
  final small = img.copyResize(photo, width: modelSize, height: modelSize, interpolation: img.Interpolation.average);
  final rgb = Uint8List(photo.width * photo.height * 3);
  var i = 0;
  for (final p in photo) {
    rgb[i++] = p.r.toInt();
    rgb[i++] = p.g.toInt();
    rgb[i++] = p.b.toInt();
  }
  final input = Float32List(modelSize * modelSize * 3);
  i = 0;
  for (final p in small) {
    input[i++] = p.r / 255;
    input[i++] = p.g / 255;
    input[i++] = p.b / 255;
  }
  return PreparedPhoto(rgb, photo.width, photo.height, input);
}

/// Clothes-class probability map (256x256) from the raw model output (256*256*6).
/// Applies softmax only if the output looks like logits.
Float32List clothesProbability(Float32List out) {
  final n = modelSize * modelSize;
  final sample = out[0] + out[1] + out[2] + out[3] + out[4] + out[5];
  final isProb = (sample - 1).abs() < 0.02;
  final res = Float32List(n);
  for (var p = 0; p < n; p++) {
    final o = p * _classes;
    if (isProb) {
      res[p] = out[o + _clothesClass];
    } else {
      var mx = out[o];
      for (var c = 1; c < _classes; c++) {
        mx = math.max(mx, out[o + c]);
      }
      var sum = 0.0;
      for (var c = 0; c < _classes; c++) {
        sum += math.exp(out[o + c] - mx);
      }
      res[p] = math.exp(out[o + _clothesClass] - mx) / sum;
    }
  }
  return res;
}

class BuildArgs {
  BuildArgs(this.rgb, this.w, this.h, this.prob);
  final Uint8List rgb;
  final int w, h;
  final Float32List prob;
}

/// File name -> encoded bytes: cutout_both.png, portrait.jpg, split.txt (waist as a fraction of image height), shading.png, shading_mul.png, thumb.jpg.
Future<Map<String, Uint8List>> buildPortraitAssets(BuildArgs a) => Isolate.run(() => _build(a));

Map<String, Uint8List> _build(BuildArgs a) {
  final w = a.w, h = a.h;
  final mask = _largestComponent(_threshold(_upscale(a.prob, w, h)), w, h);
  var y0 = h, y1 = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (mask[y * w + x] != 0) {
        y0 = math.min(y0, y);
        y1 = y;
        break;
      }
    }
  }
  if (y1 < 0 || (y1 - y0) < h * 0.1) throw NoClothesFound();
  final split = (y0 + _waistFraction * (y1 - y0)).round(); // starting guess; the user drags it

  final out = <String, Uint8List>{};
  final m = _soft(Float32List.fromList([for (final v in mask) v.toDouble()]), w, h);
  final rgba = Uint8List(w * h * 4);
  for (var p = 0; p < w * h; p++) {
    rgba[p * 4] = a.rgb[p * 3];
    rgba[p * 4 + 1] = a.rgb[p * 3 + 1];
    rgba[p * 4 + 2] = a.rgb[p * 3 + 2];
    rgba[p * 4 + 3] = ((1 - m[p]) * 255).round();
  }
  out['cutout_both.png'] = img.encodePng(img.Image.fromBytes(width: w, height: h, bytes: rgba.buffer, numChannels: 4));
  // opaque original, used to hide the part of the garment the user excludes (torso/legs split)
  out['portrait.jpg'] = img.encodeJpg(img.Image.fromBytes(width: w, height: h, bytes: a.rgb.buffer, numChannels: 3), quality: 92);
  out['split.txt'] = Uint8List.fromList((split / h).toStringAsFixed(4).codeUnits);

  // shading = garment luminance / its mean, darken-only; blurred variant keeps broad folds only
  final maskF = Float32List(w * h);
  for (var p = 0; p < w * h; p++) {
    maskF[p] = mask[p].toDouble();
  }
  final ms = _soft(maskF, w, h);
  final lum = Float32List(w * h);
  var sum = 0.0, cnt = 0;
  for (var p = 0; p < w * h; p++) {
    lum[p] = 0.299 * a.rgb[p * 3] + 0.587 * a.rgb[p * 3 + 1] + 0.114 * a.rgb[p * 3 + 2];
    if (ms[p] > 0.5) {
      sum += lum[p];
      cnt++;
    }
  }
  final mean = cnt == 0 ? 128.0 : sum / cnt;
  final ratio = Float32List(w * h);
  for (var p = 0; p < w * h; p++) {
    ratio[p] = (lum[p] / mean).clamp(0.0, 1.0);
  }
  Float32List toMap(Float32List r) {
    final res = Float32List(w * h);
    for (var p = 0; p < w * h; p++) {
      res[p] = r[p] * ms[p] + (1 - ms[p]);
    }
    return res;
  }

  final num = Float32List(w * h);
  for (var p = 0; p < w * h; p++) {
    num[p] = ratio[p] * ms[p];
  }
  final bn = _boxBlur3(num, w, h, 10), bd = _boxBlur3(ms, w, h, 10);
  final blurred = Float32List(w * h);
  for (var p = 0; p < w * h; p++) {
    blurred[p] = (bn[p] / math.max(bd[p], 1e-3)).clamp(0.0, 1.0);
  }
  out['shading_mul.png'] = _gray(toMap(ratio), w, h);
  out['shading.png'] = _gray(toMap(blurred), w, h);

  final thumb = img.copyResize(img.Image.fromBytes(width: w, height: h, bytes: a.rgb.buffer, numChannels: 3), width: 200);
  out['thumb.jpg'] = img.encodeJpg(thumb, quality: 80);
  return out;
}

Uint8List _gray(Float32List f, int w, int h) {
  final rgb = Uint8List(w * h * 3);
  for (var p = 0; p < w * h; p++) {
    final v = (f[p].clamp(0.0, 1.0) * 255).round();
    rgb[p * 3] = v;
    rgb[p * 3 + 1] = v;
    rgb[p * 3 + 2] = v;
  }
  return img.encodePng(img.Image.fromBytes(width: w, height: h, bytes: rgb.buffer, numChannels: 3));
}

Float32List _upscale(Float32List src, int w, int h) {
  final res = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    final fy = ((y + 0.5) * modelSize / h - 0.5).clamp(0.0, modelSize - 1.0);
    final y0 = fy.floor(), y1 = math.min(y0 + 1, modelSize - 1), ty = fy - y0;
    for (var x = 0; x < w; x++) {
      final fx = ((x + 0.5) * modelSize / w - 0.5).clamp(0.0, modelSize - 1.0);
      final x0 = fx.floor(), x1 = math.min(x0 + 1, modelSize - 1), tx = fx - x0;
      final top = src[y0 * modelSize + x0] * (1 - tx) + src[y0 * modelSize + x1] * tx;
      final bot = src[y1 * modelSize + x0] * (1 - tx) + src[y1 * modelSize + x1] * tx;
      res[y * w + x] = top * (1 - ty) + bot * ty;
    }
  }
  return res;
}

Uint8List _threshold(Float32List f) {
  final m = Uint8List(f.length);
  for (var i = 0; i < f.length; i++) {
    m[i] = f[i] >= 0.5 ? 1 : 0;
  }
  return m;
}

/// Keep only the biggest 8-connected blob.
Uint8List _largestComponent(Uint8List m, int w, int h) {
  final label = Int32List(w * h);
  final stack = Int32List(w * h);
  var best = 0, bestSize = 0, next = 0;
  for (var s = 0; s < w * h; s++) {
    if (m[s] == 0 || label[s] != 0) continue;
    next++;
    var sp = 0, size = 0;
    stack[sp++] = s;
    label[s] = next;
    while (sp > 0) {
      final p = stack[--sp];
      size++;
      final px = p % w, py = p ~/ w;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = px + dx, ny = py + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final q = ny * w + nx;
          if (m[q] != 0 && label[q] == 0) {
            label[q] = next;
            stack[sp++] = q;
          }
        }
      }
    }
    if (size > bestSize) {
      bestSize = size;
      best = next;
    }
  }
  final res = Uint8List(w * h);
  if (best == 0) return res;
  for (var i = 0; i < w * h; i++) {
    res[i] = label[i] == best ? 1 : 0;
  }
  return res;
}

/// Dilate ~2 px then feather ~1.5 px, same as the spike-2 assets.
Float32List _soft(Float32List m, int w, int h) => _boxBlur3(_dilate(m, w, h, 2), w, h, 1);

Float32List _dilate(Float32List m, int w, int h, int r) {
  Float32List pass(Float32List src, bool horizontal) {
    final res = Float32List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var v = 0.0;
        for (var k = -r; k <= r; k++) {
          final xx = horizontal ? x + k : x, yy = horizontal ? y : y + k;
          if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
          v = math.max(v, src[yy * w + xx]);
        }
        res[y * w + x] = v;
      }
    }
    return res;
  }

  return pass(pass(m, true), false);
}

/// Three box blurs of radius r approximate a Gaussian with sigma ~ r.
Float32List _boxBlur3(Float32List f, int w, int h, int r) {
  var cur = f;
  for (var i = 0; i < 3; i++) {
    cur = _boxBlur(_boxBlur(cur, w, h, r, true), w, h, r, false);
  }
  return cur;
}

Float32List _boxBlur(Float32List src, int w, int h, int r, bool horizontal) {
  final res = Float32List(w * h);
  final lines = horizontal ? h : w, len = horizontal ? w : h;
  for (var l = 0; l < lines; l++) {
    int idx(int i) => horizontal ? l * w + i : i * w + l;
    var sum = 0.0;
    for (var i = -r; i <= r; i++) {
      sum += src[idx(i.clamp(0, len - 1))];
    }
    for (var i = 0; i < len; i++) {
      res[idx(i)] = sum / (2 * r + 1);
      sum += src[idx(math.min(i + r + 1, len - 1))] - src[idx(math.max(i - r, 0))];
    }
  }
  return res;
}
