// lib/app/modules/customization/views/customization_screen.dart

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/service/audio_service.dart';
import 'controllers/customization_controller.dart';

class CustomizationScreen extends GetView<CustomizationController> {
  const CustomizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AudioService audioService = Get.find<AudioService>();
    return Scaffold(
      backgroundColor: const Color(0xFF0E143F),
      appBar: AppBar(
        // title: const Text('Customize Snake'),
        leading: IconButton(onPressed: ()=> {audioService.playButtonClick(),Get.back()}, icon: const Icon(Icons.arrow_back_ios_new,color: Colors.white,)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: controller.animationController,
                  builder: (context, child) {
                    return Obx(
                          () => SnakePreview(
                        skinColors: controller.allSkins[controller.tempSelectedSkinIndex.value],
                        headUIImage: controller.loadedHeadImage.value,
                        animationValue: controller.animationController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Skins', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildSkinSelector(),
                  const SizedBox(height: 24),
                  const Text('Heads', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildHeadSelector(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: controller.saveChanges,
                      child: const Text('Save & Exit', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkinSelector() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: controller.allSkins.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => controller.selectSkin(index),
            child: Obx(() {
              final isSelected = controller.tempSelectedSkinIndex.value == index;
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: controller.allSkins[index]),
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected ? Border.all(color: Colors.yellowAccent, width: 3) : null,
                  boxShadow: isSelected ? [ const BoxShadow( color: Colors.yellowAccent, blurRadius: 10, spreadRadius: 1,) ] : [],
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildHeadSelector() {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: controller.allHeads.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => controller.selectHead(index),
            child: Obx(() {
              final isSelected = controller.tempSelectedHeadIndex.value == index;
              return Container(
                width: 70,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected ? Border.all(color: Colors.yellowAccent, width: 3) : null,
                  boxShadow: isSelected ? [ const BoxShadow( color: Colors.yellowAccent, blurRadius: 10, spreadRadius: 1, )] : [],
                ),
                child: Image.asset('assets/images/${controller.allHeads[index]}'),
              );
            }),
          );
        },
      ),
    );
  }
}

class SnakePreview extends StatelessWidget {
  final List<Color> skinColors;
  final ui.Image? headUIImage;
  final double animationValue;

  const SnakePreview({
    super.key,
    required this.skinColors,
    this.headUIImage,
    required this.animationValue,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 250,
      child: CustomPaint(
        painter: SnakePainter(
          skinColors: skinColors,
          headUIImage: headUIImage,
          animationValue: animationValue,
        ),
      ),
    );
  }
}

class SnakePainter extends CustomPainter {
  final List<Color> skinColors;
  final ui.Image? headUIImage;
  final double animationValue;

  SnakePainter({
    required this.skinColors,
    this.headUIImage,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 15.0;
    const spacing = radius * 0.4;

    // --- FIX: Replaced the curve with a straight line ---
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.2); // Start (tail)
    path.lineTo(size.width * 0.8, size.height * 0.8); // End (head)

    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;
    final segmentCount = (totalLength / spacing).floor();

    final animationOffset = animationValue * 2 * pi;

    for (int i = 0; i < segmentCount; i++) {
      final distance = i * spacing;
      final tangent = metrics.getTangentForOffset(distance);
      if (tangent == null) continue;

      final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
      final waveAmplitude = 10.0;
      final waveOffset = sin((distance * 0.1) - animationOffset) * waveAmplitude;
      final renderPosition = tangent.position + (normal * waveOffset);

      final color = skinColors[i % skinColors.length];
      final paint = Paint()..shader = RadialGradient(colors: [color, color.withOpacity(0.6)]).createShader(Rect.fromCircle(center: renderPosition, radius: radius));
      canvas.drawCircle(renderPosition, radius, paint);
    }

    final headTangent = metrics.getTangentForOffset(totalLength);
    if (headTangent == null) return;

    final normal = Offset(-headTangent.vector.dy, headTangent.vector.dx);
    final waveAmplitude = 10.0;
    final waveOffset = sin((totalLength * 0.1) - animationOffset) * waveAmplitude;
    final headPosition = headTangent.position + (normal * waveOffset);

    if (headUIImage != null) {
      const headRadius = 16.0;
      final direction = headTangent.angle;

      canvas.save();
      canvas.translate(headPosition.dx, headPosition.dy);
      canvas.rotate(direction + pi / 10);

      final rect = Rect.fromCircle(center: Offset.zero, radius: headRadius);
      paintImage(canvas: canvas, rect: rect, image: headUIImage!, fit: BoxFit.contain, filterQuality: FilterQuality.high);
      canvas.restore();
    } else {
      final headPaint = Paint()..color = skinColors.first;
      canvas.drawCircle(headPosition, 14, headPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SnakePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.headUIImage != headUIImage ||
        oldDelegate.skinColors != skinColors;
  }
}