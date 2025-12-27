import 'package:flutter/material.dart';

/// 사용자가 정의할 수 있는 버튼 모델
class CustomButton {
  final String id;
  final String abbreviation; // K, P, M1L, M1R 등
  final String koreanName; // 겉뜨기, 안뜨기 등
  final Color color;

  const CustomButton({
    required this.id,
    required this.abbreviation,
    required this.koreanName,
    required this.color,
  });

  CustomButton copyWith({
    String? id,
    String? abbreviation,
    String? koreanName,
    Color? color,
  }) {
    return CustomButton(
      id: id ?? this.id,
      abbreviation: abbreviation ?? this.abbreviation,
      koreanName: koreanName ?? this.koreanName,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'abbreviation': abbreviation,
      'koreanName': koreanName,
      'color': color.value,
    };
  }

  factory CustomButton.fromJson(Map<String, dynamic> json) {
    return CustomButton(
      id: json['id'] as String,
      abbreviation: json['abbreviation'] as String,
      koreanName: json['koreanName'] as String,
      color: Color(json['color'] as int),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomButton && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 기본 제공 버튼 프리셋 목록
class ButtonPresets {
  static final List<CustomButton> all = [
    const CustomButton(
      id: 'knit',
      abbreviation: 'K',
      koreanName: '겉뜨기',
      color: Colors.white,
    ),
    const CustomButton(
      id: 'purl',
      abbreviation: 'P',
      koreanName: '안뜨기',
      color: Colors.white,
    ),
    const CustomButton(
      id: 'm1l',
      abbreviation: 'M1L',
      koreanName: '오른코늘리기',
      color: Colors.white,
    ),
    const CustomButton(
      id: 'm1r',
      abbreviation: 'M1R',
      koreanName: '왼코늘리기',
      color: Colors.white,
    ),
    const CustomButton(
      id: 'ssk',
      abbreviation: 'SSK',
      koreanName: '왼코모으기',
      color: Colors.white,
    ),
    const CustomButton(
      id: 'k2tog',
      abbreviation: 'K2tog',
      koreanName: '오른코모으기',
      color: Colors.white,
    ),
    const CustomButton(
      id: 'yo',
      abbreviation: 'YO',
      koreanName: '감아올리기',
      color: Colors.white,
    ),
    const CustomButton(
      id: 'sl',
      abbreviation: 'SL',
      koreanName: '옮기기',
      color: Colors.white,
    ),
  ];

  static CustomButton get knit => all.firstWhere((b) => b.id == 'knit');
  static CustomButton get purl => all.firstWhere((b) => b.id == 'purl');
}
