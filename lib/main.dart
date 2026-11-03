import 'package:flutter/material.dart';
import 'package:swatchwear/spike/fps_spike_page.dart';

void main() => runApp(const SwatchwearApp());

class SwatchwearApp extends StatelessWidget {
  const SwatchwearApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Swatchwear',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFF0F0F0E),
          colorScheme: const ColorScheme.dark(primary: Color(0xFFD7F94A)),
        ),
        home: const FpsSpikePage(),
      );
}
