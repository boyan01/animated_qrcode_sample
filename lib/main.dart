import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class QrCodeData {
  QrCodeData(this.data, {int segmentLength = 300}) : segments = [] {
    var offset = 0;
    while (offset < data.length) {
      final end = math.min(offset + segmentLength, data.length);
      segments.add(data.substring(offset, end));
      offset = end;
    }
    if (segments.isEmpty) {
      segments.add('');
    }
  }

  final String data;

  final List<String> segments;
}

class _MyHomePageState extends State<MyHomePage> {
  final _dataController = TextEditingController();
  final _durationController = TextEditingController(text: '600');
  final _segmentLengthController = TextEditingController(text: "200");

  var _index = 0;
  QrCodeData _data = QrCodeData('');

  @override
  void initState() {
    super.initState();
    _dataController.addListener(_onDataChanged);
    _durationController.addListener(_onDataChanged);
    _segmentLengthController.addListener(_onDataChanged);
    _dataController.text = 'Hello World!';
  }

  void _onDataChanged() {
    final segmentLength =
        int.tryParse(_segmentLengthController.text.trim()) ?? 200;
    final duration = int.tryParse(_durationController.text.trim()) ?? 600;
    _data =
        QrCodeData(_dataController.text.trim(), segmentLength: segmentLength);
    debugPrint('data: $segmentLength $duration ${_data.segments.length}');
    _performAnimation(duration: duration);
  }

  Timer? _timer;

  void _performAnimation({required int duration}) {
    _timer?.cancel();
    _index = 0;
    _timer = Timer.periodic(Duration(milliseconds: duration), (timer) {
      setState(() {
        _index = (_index + 1) % _data.segments.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dataController.removeListener(_onDataChanged);
    _durationController.removeListener(_onDataChanged);
    _segmentLengthController.removeListener(_onDataChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            QrImageView(
              data:
                  '${_index + 1}/${_data.segments.length}|${_data.segments[_index]}',
              size: 200,
            ),
            Text('${_index + 1}/${_data.segments.length}'),
            const SizedBox(height: 16),
            SizedBox(
              width: 400,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration(ms)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _segmentLengthController,
                      decoration: const InputDecoration(
                        labelText: 'Segment Length',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
                minHeight: 0,
              ),
              child: TextField(
                controller: _dataController,
                decoration: const InputDecoration(
                  labelText: 'Data',
                  border: OutlineInputBorder(),
                ),
                maxLines: 7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
