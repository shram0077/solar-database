import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ColorfulText extends StatefulWidget {
  final String text;
  const ColorfulText({Key? key, required this.text}) : super(key: key);

  @override
  _ColorfulTextState createState() => _ColorfulTextState();
}

class _ColorfulTextState extends State<ColorfulText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(); // loop animation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Colors.purple,
                Colors.blue,
                Colors.green,
                Colors.orange,
                Colors.red,
              ],
              begin: Alignment(-1.0 + _controller.value * 2, 0.0),
              end: Alignment(1.0 + _controller.value * 2, 0.0),
              tileMode: TileMode.mirror,
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: GoogleFonts.inter(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white, // Important for ShaderMask
            ),
          ),
        );
      },
    );
  }
}
