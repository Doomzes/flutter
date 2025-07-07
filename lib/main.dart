import 'package:flutter/material.dart';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

void main() {
  runApp(const GuitarTunerApp());
}

class GuitarTunerApp extends StatelessWidget {
  const GuitarTunerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guitar Tuner',
      theme: ThemeData.dark().copyWith(
        useMaterial3: true,
      ),
      home: const TunerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Tuning {
  final String name;
  final List<String> strings;

  Tuning(this.name, this.strings);
}

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen>
    with SingleTickerProviderStateMixin {
  final List<Tuning> tunings = [
    Tuning('E', ['E', 'B', 'G', 'D', 'A', 'E']),
    Tuning('Drop D', ['E', 'B', 'G', 'D', 'A', 'D']),
    Tuning('Half-step Down', ['D#', 'A#', 'F#', 'C#', 'G#', 'D#']),
    Tuning('Drop C#', ['F#', 'C#', 'G#', 'D', 'A', 'C#']),
    Tuning('Drop C', ['G', 'C', 'F', 'A#', 'D', 'C']),
    Tuning('Drop B', ['F#', 'B', 'E', 'A', 'D', 'B']),
    Tuning('Drop A', ['E', 'A', 'D', 'G', 'B', 'A']),
    Tuning('Open C', ['E', 'C', 'G', 'C', 'G', 'C']),
    Tuning('Open E', ['E', 'B', 'G#', 'E', 'B', 'E']),
    Tuning('Open F', ['F', 'A', 'C', 'F', 'C', 'F']),
    Tuning('Open G', ['D', 'G', 'D', 'G', 'B', 'D']),
    Tuning('Open A', ['E', 'A', 'E', 'A', 'C#', 'E']),
    Tuning('Open Am', ['E', 'A', 'E', 'A', 'C', 'E']),
    Tuning('Open Em', ['E', 'B', 'E', 'G', 'B', 'E']),
    Tuning('Open D', ['D', 'A', 'D', 'F#', 'A', 'D']),
    Tuning('Open Dm', ['D', 'A', 'D', 'F', 'A', 'D']),
  ];
  final List<double> standardFrequencies = [82.41, 110.00, 146.83, 196.00, 246.94, 329.63];
  double detectedFrequency = 0.0;
  List<double> audioBuffer = [];
  final int bufferSize = 2048; // ~46мс при 44.1кГц
  final ScrollController _scrollController = ScrollController();
  Tuning? selectedTuning;
  bool isTuning = false;
  double angle = 0.0;
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();

  int currentString = 0; // 1-я струна = индекс 0 (слева и внизу)
  List<bool> tuned = List.generate(6, (_) => false);
  double deviation = 0.0;

  @override
  void initState() {
    super.initState();
    requestMicrophonePermission();
    selectedTuning = tunings.first; // <-- Дефолтный строй, если вдруг не выбран
  }

  List<double> getFrequenciesForTuning(String tuningName) {
    switch (tuningName) {
      case 'E':
        // Standard: E2, A2, D3, G3, B3, E4
        return [82.41, 110.00, 146.83, 196.00, 246.94, 329.63];
      case 'Drop D':
        // D2, A2, D3, G3, B3, E4
        return [73.42, 110.00, 146.83, 196.00, 246.94, 329.63];
      case 'Half-step Down':
        // Eb2, Ab2, Db3, Gb3, Bb3, Eb4 (на полтона ниже)
        return [77.78, 103.83, 138.59, 185.00, 233.08, 311.13];
      case 'Drop C#':
        // C#2, G#2, C#3, F#3, A#3, D#4
        // (обычно "Drop C#", строится как Half-step Down Drop D)
        return [69.30, 103.83, 138.59, 185.00, 233.08, 311.13];
      case 'Drop C':
        // C2, G2, C3, F3, A3, D4
        return [65.41, 98.00, 130.81, 174.61, 220.00, 293.66];
      case 'Drop B':
        // B1, F#2, B2, E3, A3, D3
        // Часто встречается и как [61.74, 92.50, 123.47, 164.81, 220.00, 293.66]
        return [61.74, 92.50, 123.47, 164.81, 220.00, 246.94];
      case 'Drop A':
        // A1, E2, A2, D3, G3, B3
        return [55.00, 82.41, 110.00, 146.83, 196.00, 246.94];
      case 'Open C':
        // C2, G2, C3, G3, C4, E4
        return [65.41, 98.00, 130.81, 196.00, 261.63, 329.63];
      case 'Open E':
        // E2, B2, E3, G#3, B3, E4
        return [82.41, 123.47, 164.81, 207.65, 246.94, 329.63];
      case 'Open F':
        // F2, A2, C3, F3, C4, F4
        return [87.31, 110.00, 130.81, 174.61, 261.63, 349.23];
      case 'Open G':
        // D2, G2, D3, G3, B3, D4
        return [73.42, 98.00, 146.83, 196.00, 246.94, 293.66];
      case 'Open A':
        // E2, A2, E3, A3, C#4, E4
        return [82.41, 110.00, 164.81, 220.00, 277.18, 329.63];
      case 'Open Am':
        // E2, A2, E3, A3, C4, E4
        return [82.41, 110.00, 164.81, 220.00, 261.63, 329.63];
      case 'Open Em':
        // E2, B2, E3, G3, B3, E4
        return [82.41, 123.47, 164.81, 196.00, 246.94, 329.63];
      case 'Open D':
        // D2, A2, D3, F#3, A3, D4
        return [73.42, 110.00, 146.83, 185.00, 220.00, 293.66];
      case 'Open Dm':
        // D2, A2, D3, F3, A3, D4
        return [73.42, 110.00, 146.83, 174.61, 220.00, 293.66];
      default:
        // Стандарт E
        return [82.41, 110.00, 146.83, 196.00, 246.94, 329.63];
    }
  }

  double detectFrequency(List<double> buffer, int sampleRate) {
    int n = buffer.length;
    double maxCorr = 0.0;
    int bestLag = 0;
    int minLag = sampleRate ~/ 1000; // 1000 Гц (верхняя граница)
    int maxLag = sampleRate ~/ 50;   // 50 Гц (нижняя граница)

    for (int lag = minLag; lag < maxLag; lag++) {
      double corr = 0.0;
      for (int i = 0; i < n - lag; i++) {
        corr += buffer[i] * buffer[i + lag];
      }
      if (corr > maxCorr) {
        maxCorr = corr;
        bestLag = lag;
      }
    }

    if (bestLag != 0) {
      return sampleRate / bestLag;
    }
    return 0.0;
  }
  int findClosestString(double freq, List<double> targetFreqs) {
    double minDiff = double.infinity;
    int minIdx = 0;
    for (int i = 0; i < targetFreqs.length; i++) {
      double diff = (freq - targetFreqs[i]).abs();
      if (diff < minDiff) {
        minDiff = diff;
        minIdx = i;
      }
    }
    return minIdx;
  }


  Future<void> requestMicrophonePermission() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      // 🎸 Разрешение выдано, можно работать с микрофоном!
      debugPrint('Микрофон разрешён');
    } else if (status.isDenied) {
      // Покажи диалог/снэкбар с просьбой выдать доступ!
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Требуется доступ к микрофону для настройки гитары.'),
          ),
        );
      }
    } else if (status.isPermanentlyDenied) {
      // Пользователь запретил навсегда, просим открыть настройки:
      openAppSettings();
    }
  }

  void startTuning() async {
    setState(() { isTuning = true; });
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Просто для теста UI — имитируем колебания частоты
      Future.doWhile(() async {
        if (!isTuning) return false;
        setState(() {
          detectedFrequency = 82.41 + Random().nextDouble() * 2 - 1; // +/- 1 Hz
          deviation = detectedFrequency - 82.41;
          tuned = List.generate(6, (i) => (i == currentString) && deviation.abs() < 1.0);
          angle = (deviation / 15.0).clamp(-1, 1) * pi / 6;
        });
        await Future.delayed(Duration(milliseconds: 500));
        return true;
      });
    } else {
      await _audioCapture.start(
        processAudioFrame,
        (Object e) => debugPrint('Error: $e'),
        sampleRate: 44100,
        bufferSize: bufferSize,
        audioFormat: AudioFormat.ENCODING_PCM_16BIT,
      );
    }
  }

  void stopTuning() async {
    setState(() { isTuning = false; });
    if (Platform.isAndroid || Platform.isIOS) {
      await _audioCapture.stop();
    }
  }

  void processAudioFrame(dynamic data) {
    final floats = data as Float32List;
    audioBuffer.addAll(floats);

    while (audioBuffer.length > bufferSize) {
      final segment = audioBuffer.sublist(0, bufferSize);
      final freq = detectFrequency(segment, 44100);
      List<double> targetFreqs = getFrequenciesForTuning(selectedTuning!.name);
      int closest = findClosestString(freq, targetFreqs);
      double deviationHz = freq - targetFreqs[closest];

      setState(() {
        detectedFrequency = freq;
        currentString = closest;
        deviation = deviationHz;
        tuned = List.generate(6, (i) => (i == closest) && deviationHz.abs() < 1.0);
        angle = (deviationHz / 15.0).clamp(-1, 1) * pi / 6;
      });

      audioBuffer = audioBuffer.sublist(bufferSize);
    }
  }
  void changeString(int idx) {
    setState(() {
      currentString = idx;
    });
  }


  void dispose() {
    _audioCapture.stop(); // На всякий случай — чтобы точно освободить ресурсы
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color pointerColor =
        deviation.abs() < 3 ? Colors.greenAccent : Colors.white;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              Color(0xFF1A1A40),
              Color(0xFF0F0C29),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'Guitar Tuner',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // --- Дуга и стрелка ---
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 200,
                    child: CustomPaint(
                      size: const Size(240, 120),
                      painter: GaugePainter(), // <-- ДУГА!
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    height: 200,
                    child: CustomPaint(
                      size: const Size(240, 120),
                      painter: PointerPainter(angle: angle, color: pointerColor), // <-- СТРЕЛКА!
                    ),
                  ),
                  // Название ноты чуть ниже стрелки:
                  Positioned(
                    top: 125,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        selectedTuning!.strings[currentString],
                        style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              // --- КРУЖОЧКИ СТРУН (СНИЗУ ГОРИЗОНТАЛЬНО) ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (idx) {
                    int stringNum = idx + 1; // 1 → 6
                    bool isActive = currentString == idx;
                    bool isTuned = tuned[idx];
                    return GestureDetector(
                      onTap: () => changeString(idx),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: isActive ? 38 : 32,
                        height: isActive ? 38 : 32,
                        decoration: BoxDecoration(
                          color: isTuned
                              ? Colors.greenAccent
                              : (isActive
                                  ? Colors.redAccent
                                  : Colors.transparent),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? Colors.redAccent
                                : isTuned
                                    ? Colors.greenAccent
                                    : Colors.white38,
                            width: 2,
                          ),
                          boxShadow: [
                            if (isActive)
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.4),
                                blurRadius: 12,
                              ),
                            if (isTuned)
                              BoxShadow(
                                color: Colors.greenAccent.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$stringNum',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isActive ? 20 : 16,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // --- Стандартные элементы тюнера ---
              Text(
                detectedFrequency > 0
                  ? '${detectedFrequency.toStringAsFixed(2)} Hz'
                  : '-- Hz',
                style: TextStyle(fontSize: 22),
              ),
              const Text(
                'FREQUENCY',
                style: TextStyle(fontSize: 12, letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              Text(
                deviation.abs() < 1
                    ? 'Perfect!'
                    : deviation > 0
                        ? '+${deviation.toStringAsFixed(2)} Hz'
                        : '${deviation.toStringAsFixed(2)} Hz',
                style: TextStyle(
                  fontSize: 20,
                  color: deviation.abs() < 3
                      ? Colors.greenAccent
                      : deviation.abs() < 7
                          ? Colors.orangeAccent
                          : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 55,
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    int idx = tunings.indexOf(selectedTuning!);
                    // details.velocity.pixelsPerSecond.dx < 0 — свайп влево (следующий строй)
                    // details.velocity.pixelsPerSecond.dx > 0 — свайп вправо (предыдущий строй)
                    if (details.velocity.pixelsPerSecond.dx < 0 && idx < tunings.length - 1) {
                      setState(() {
                        selectedTuning = tunings[idx + 1];
                        currentString = 0;
                        tuned = List.generate(6, (_) => false);
                      });
                      _scrollController.animateTo(
                        (idx + 1) * 120.0, // шаг зависит от ширины айтема!
                        duration: Duration(milliseconds: 300),
                        curve: Curves.ease,
                      );
                    } else if (details.velocity.pixelsPerSecond.dx > 0 && idx > 0) {
                      setState(() {
                        selectedTuning = tunings[idx - 1];
                        currentString = 0;
                        tuned = List.generate(6, (_) => false);
                      });
                      _scrollController.animateTo(
                        (idx - 1) * 120.0,
                        duration: Duration(milliseconds: 300),
                        curve: Curves.ease,
                      );
                    }
                  },
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: tunings.length,
                    controller: _scrollController,
                    itemBuilder: (context, index) {
                      final isSelected = tunings[index] == selectedTuning;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedTuning = tunings[index];
                            currentString = 0;
                            tuned = List.generate(6, (_) => false);
                          });
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.deepPurple
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.deepPurple
                                  : Colors.deepPurple.withOpacity(0.4),
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.deepPurple.withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            tunings[index].name,
                            style: TextStyle(
                              fontSize: isSelected ? 20 : 16,
                              color: isSelected ? Colors.white : Colors.deepPurple,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                  backgroundColor: Colors.deepPurple,
                ),
                onPressed: isTuning ? stopTuning : startTuning,
                child: Icon(
                  isTuning ? Icons.stop : Icons.play_arrow,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}

/// Верхняя полудуга: красный → жёлтый → зелёный (центр) → жёлтый → красный
class GaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;

    int steps = 120;
    double startAngle = -pi;
    double sweep = pi / steps;

    for (int i = 0; i < steps; i++) {
      double t = i / (steps - 1);
      Color color;
      if (t < 0.25) {
        // Красный → Жёлтый
        color = Color.lerp(Colors.redAccent, Colors.yellowAccent, t / 0.25)!;
      } else if (t < 0.5) {
        // Жёлтый → Зелёный
        color = Color.lerp(Colors.yellowAccent, Colors.greenAccent, (t - 0.25) / 0.25)!;
      } else if (t < 0.75) {
        // Зелёный → Жёлтый
        color = Color.lerp(Colors.greenAccent, Colors.yellowAccent, (t - 0.5) / 0.25)!;
      } else {
        // Жёлтый → Красный
        color = Color.lerp(Colors.yellowAccent, Colors.redAccent, (t - 0.75) / 0.25)!;
      }
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + sweep * i,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class PointerPainter extends CustomPainter {
  final double angle;
  final Color color;
  PointerPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 22;
    final start = center;
    final end = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );

    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant PointerPainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.color != color;
}
