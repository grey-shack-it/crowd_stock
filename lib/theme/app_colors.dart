import 'package:flutter/material.dart';

/// 매트 다크 & 네온 포인트 팔레트. 화면 어디서든 이 상수로만 색을 참조한다.
class AppColors {
  AppColors._();

  static const background = Color(0xFF121316);
  static const surface = Color(0xFF1E222D);
  static const primary = Color(0xFF00E676); // 메인 포인트(그린)
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF848E9C);
  static const warning = Color(0xFFFF5252); // 과열/경고
  static const high = Color.fromARGB(244, 29, 245, 1); // 높음
  static const middle = Color.fromARGB(244, 1, 237, 245); // 중간
  static const bottom = Color.fromARGB(255, 247, 169, 0); // 낮음

  // 참여 가중치 색상 구간: 1.2~1.5=높음, 0.9~1.1=보통, 0.5~0.8=낮음
  static Color confidenceColor(double? multiplier) {
    if (multiplier == null) return textSecondary;
    if (multiplier >= 1.2) return high;
    if (multiplier >= 0.9) return middle;
    return bottom;
  }

  // 0~100 percentile 점수용 3단계: 70이상=높음, 30~70=보통, 30미만=낮음
  static Color scoreColor(double? score) {
    if (score == null) return textSecondary;
    if (score >= 70) return high;
    if (score >= 30) return middle;
    return bottom;
  }

  // 프리즘 지수 전용(0~150 스케일): scoreColor와 같은 비율(70%/30% 지점)을
  // 150 기준으로 다시 잡은 것 — 105 이상=높음, 45~105=보통, 45 미만=낮음
  static Color prismIndexColor(double? score) {
    if (score == null) return textSecondary;
    if (score >= 105) return high;
    if (score >= 45) return middle;
    return bottom;
  }
}
