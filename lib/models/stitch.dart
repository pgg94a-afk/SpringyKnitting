import 'package:flutter/material.dart';
import 'custom_button.dart';

/// 하나의 스티치(코)를 나타내는 클래스
class Stitch {
  final String abbreviation;
  final String koreanName;
  final Color color;

  const Stitch({
    required this.abbreviation,
    required this.koreanName,
    required this.color,
  });

  /// CustomButton으로부터 Stitch 생성
  factory Stitch.fromButton(CustomButton button) {
    return Stitch(
      abbreviation: button.abbreviation,
      koreanName: button.koreanName,
      color: button.color,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'abbreviation': abbreviation,
      'koreanName': koreanName,
      'color': color.value,
    };
  }

  factory Stitch.fromJson(Map<String, dynamic> json) {
    return Stitch(
      abbreviation: json['abbreviation'] as String,
      koreanName: json['koreanName'] as String,
      color: Color(json['color'] as int),
    );
  }
}
