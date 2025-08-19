import 'package:flutter/material.dart';

Widget titletext(
  String text, {
  Color color = Colors.black87,
  double fontSize = 13,
}) {
  return Text(
    text,
    style: TextStyle(
      fontFamily: 'K24KurdishBold',
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: color,
    ),
  );
}
