import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

const demonstrationTitles = [
  'Moonlit District',
  'Atlas Nine',
  'The Last Orchard',
  'Tides of Glass',
  'Paper Cities',
  'Aster & Ash',
  'Beyond the Pines',
  'Blue Meridian',
  'Copper Sky',
  'The Silent Harbour',
  'Winter Letters',
  'Wildwood Station',
  'The Clockmaker',
  'Red Horizon',
  'Lantern Road',
  'The Glass Garden',
  'Solstice',
  'The Lost Observatory',
  'Ember Valley',
  'A Map of Rain',
  'Northern Lights',
  'The Jade Compass',
  'Distant Shores',
  'The Midnight Library',
];
const _palettes = [
  [Color(0xff152c46), Color(0xffd6b778), Color(0xff4b7299)],
  [Color(0xffb74e35), Color(0xfffee1a1), Color(0xffef985c)],
  [Color(0xff243f36), Color(0xffe6d4a2), Color(0xff658467)],
  [Color(0xff184856), Color(0xffdcddb0), Color(0xff4f9da0)],
  [Color(0xff593c57), Color(0xfff2d0b0), Color(0xffa2788d)],
  [Color(0xff40333e), Color(0xfff5d3a0), Color(0xffbc7458)],
  [Color(0xff263c36), Color(0xffe0d8b9), Color(0xff6f8e72)],
  [Color(0xff1b3b68), Color(0xffe6dfc4), Color(0xff5582b3)],
];

Future<Uint8List> demonstrationCover(int index) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final palette = _palettes[index % _palettes.length];
  final paint = Paint()..color = palette[0];
  canvas.drawRect(const Rect.fromLTWH(0, 0, 480, 690), paint);
  canvas.drawCircle(
    Offset(320 - index % 3 * 65, 210 + index % 2 * 45),
    90,
    paint..color = palette[1],
  );
  // Layered terrain and a skyline create distinct covers without real books.
  for (var layer = 0; layer < 3; layer++) {
    final path = Path()..moveTo(0, 690);
    for (var x = 0; x <= 480; x += 24) {
      path.lineTo(
        x.toDouble(),
        420 + layer * 65 - math.sin(x / 90 + index + layer) * 50,
      );
    }
    path.lineTo(480, 690);
    path.close();
    canvas.drawPath(
      path,
      paint..color = Color.lerp(palette[2], palette[0], layer * .3)!,
    );
  }
  if (index.isEven) {
    for (var column = 0; column < 11; column++) {
      final height = 80.0 + (column * 47 + index * 23) % 150;
      canvas.drawRect(
        Rect.fromLTWH(column * 48.0 - 8, 565 - height, 32, height),
        paint..color = palette[0],
      );
    }
  }
  final title = TextPainter(
    text: TextSpan(
      text: demonstrationTitles[index].toUpperCase(),
      style: TextStyle(
        fontFamily: 'LibreBaskerville',
        fontSize: 39,
        height: 1.13,
        color: palette[1],
        letterSpacing: 1.3,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 400);
  title.paint(canvas, const Offset(36, 36));
  title.dispose();
  final caption = TextPainter(
    text: TextSpan(
      text: 'INKORA  /  SAMPLE EDITION  0${index + 1}',
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 15,
        color: palette[1],
        letterSpacing: 2,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 420);
  caption.paint(canvas, const Offset(36, 646));
  caption.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage(480, 690);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}
