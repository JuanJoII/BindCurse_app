import 'dart:math' as math;
import 'dart:typed_data';

/// Real-time spectrum analyzer: radix-2 FFT over the most recent [fftSize]
/// samples (Hann window) grouped into logarithmic frequency bands.
class SpectrumAnalyzer {
  SpectrumAnalyzer({
    this.sampleRate = 48000,
    this.fftSize = 2048,
    this.bandCount = 15,
    this.minFreq = 60,
    this.maxFreq = 16000,
    this.floorDb = -80,
    this.ceilingDb = -10,
  })  : assert(fftSize > 0 && (fftSize & (fftSize - 1)) == 0),
        _mask = fftSize - 1,
        _ring = Float64List(fftSize),
        _re = Float64List(fftSize),
        _im = Float64List(fftSize),
        _window = Float64List(fftSize),
        _cos = Float64List(fftSize ~/ 2),
        _sin = Float64List(fftSize ~/ 2),
        _bitRev = Int32List(fftSize),
        _bandStart = Int32List(bandCount),
        _bandEnd = Int32List(bandCount),
        _bandTiltDb = Float64List(bandCount),
        _levels = Float64List(bandCount) {
    _init();
  }

  final int sampleRate;
  final int fftSize;
  final int bandCount;
  final double minFreq;
  final double maxFreq;
  final double floorDb;
  final double ceilingDb;

  final int _mask;
  final Float64List _ring;
  final Float64List _re;
  final Float64List _im;
  final Float64List _window;
  final Float64List _cos;
  final Float64List _sin;
  final Int32List _bitRev;
  final Int32List _bandStart;
  final Int32List _bandEnd;
  final Float64List _bandTiltDb;
  final Float64List _levels;
  double _windowSum = 0;
  int _writePos = 0;

  void _init() {
    final n = fftSize;
    for (var i = 0; i < n; i++) {
      _window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
      _windowSum += _window[i];
    }
    for (var j = 0; j < n ~/ 2; j++) {
      _cos[j] = math.cos(2 * math.pi * j / n);
      _sin[j] = math.sin(2 * math.pi * j / n);
    }
    final bits = (math.log(n) / math.ln2).round();
    for (var i = 0; i < n; i++) {
      var r = 0;
      var x = i;
      for (var b = 0; b < bits; b++) {
        r = (r << 1) | (x & 1);
        x >>= 1;
      }
      _bitRev[i] = r;
    }

    final binHz = sampleRate / n;
    final ratio = maxFreq / minFreq;
    var prevEnd = 1;
    for (var b = 0; b < bandCount; b++) {
      final fLo = minFreq * math.pow(ratio, b / bandCount);
      final fHi = minFreq * math.pow(ratio, (b + 1) / bandCount);
      var start = math.max(prevEnd, (fLo / binHz).round());
      var end = math.max(start + 1, (fHi / binHz).round());
      end = math.min(end, n ~/ 2);
      start = math.min(start, end - 1);
      _bandStart[b] = start;
      _bandEnd[b] = end;
      prevEnd = end;
      // +3 dB/octave tilt around 1 kHz so voice energy looks balanced.
      final center = math.sqrt(fLo * fHi);
      _bandTiltDb[b] = 3.0 * (math.log(center / 1000.0) / math.ln2);
    }
  }

  void reset() {
    _ring.fillRange(0, fftSize, 0);
    _levels.fillRange(0, bandCount, 0);
    _writePos = 0;
  }

  /// Adds one normalized sample in the range [-1, 1].
  void addSample(double sample) {
    _ring[_writePos] = sample;
    _writePos = (_writePos + 1) & _mask;
  }

  /// Runs the FFT and returns normalized band levels in [0, 1].
  List<double> computeBands() {
    final n = fftSize;
    for (var i = 0; i < n; i++) {
      final j = _bitRev[i];
      _re[j] = _ring[(_writePos + i) & _mask] * _window[i];
      _im[j] = 0;
    }

    for (var size = 2; size <= n; size <<= 1) {
      final half = size >> 1;
      final step = n ~/ size;
      for (var start = 0; start < n; start += size) {
        for (var k = 0; k < half; k++) {
          final tr = _cos[k * step];
          final ti = -_sin[k * step];
          final a = start + k;
          final b = a + half;
          final xr = _re[b] * tr - _im[b] * ti;
          final xi = _re[b] * ti + _im[b] * tr;
          _re[b] = _re[a] - xr;
          _im[b] = _im[a] - xi;
          _re[a] += xr;
          _im[a] += xi;
        }
      }
    }

    final norm = 2.0 / _windowSum;
    final range = ceilingDb - floorDb;
    for (var band = 0; band < bandCount; band++) {
      var peak = 0.0;
      for (var bin = _bandStart[band]; bin < _bandEnd[band]; bin++) {
        final mag =
            math.sqrt(_re[bin] * _re[bin] + _im[bin] * _im[bin]) * norm;
        if (mag > peak) peak = mag;
      }
      final db = 20 * math.log(math.max(peak, 1e-9)) / math.ln10 +
          _bandTiltDb[band];
      _levels[band] = ((db - floorDb) / range).clamp(0.0, 1.0);
    }
    return _levels;
  }
}
