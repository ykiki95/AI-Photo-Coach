import 'dart:io';
import 'package:flutter/material.dart';
import '../models/detected_object.dart';

class ResultScreen extends StatelessWidget {
  final String imagePath;
  final int score;
  final SceneInfo scene;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.score,
    required this.scene,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 촬영된 이미지
          Image.file(
            File(imagePath),
            fit: BoxFit.cover,
          ),

          // 상단: 점수 카드
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // 점수
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: score >= 90
                          ? const Color(0xFF22C55E).withOpacity(0.2)
                          : score >= 70
                          ? const Color(0xFFEAB308).withOpacity(0.2)
                          : const Color(0xFFEF4444).withOpacity(0.2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$score',
                      style: TextStyle(
                        color: score >= 90
                            ? const Color(0xFF22C55E)
                            : score >= 70
                            ? const Color(0xFFEAB308)
                            : const Color(0xFFEF4444),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${scene.icon} ${scene.label} 모드',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          score >= 90 ? '훌륭한 구도입니다!' :
                          score >= 70 ? '좋은 구도예요' : '구도를 더 개선해 보세요',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단: 버튼들
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 24,
            right: 24,
            child: Row(
              children: [
                // 다시 촬영
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('다시 촬영'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 저장
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('갤러리에 저장되었습니다')),
                      );
                    },
                    icon: const Icon(Icons.save_alt),
                    label: const Text('저장'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}