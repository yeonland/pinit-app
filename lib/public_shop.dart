import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// 공공데이터(소상공인 상가정보) 샵 한 곳 (assets/data/public_shops.json 한 줄, tool/fetch_shops.py 로 생성)
class PublicShop {
  final String id;
  final String name;
  final String category; // shopCategories 중 하나
  final String address;
  final String floor;
  final double lat;
  final double lng;

  const PublicShop({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.floor,
    required this.lat,
    required this.lng,
  });

  /// 화면에 보여줄 전체 주소 (층 포함)
  String get fullAddress => floor.isEmpty ? address : '$address $floor';

  factory PublicShop.fromJson(Map<String, dynamic> json) {
    return PublicShop(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      address: json['address'] as String,
      floor: (json['floor'] as String?) ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

/// assets 폴더의 JSON을 읽어서 샵 목록으로 바꿔줌
Future<List<PublicShop>> loadPublicShops() async {
  final text = await rootBundle.loadString('assets/data/public_shops.json');
  final list = jsonDecode(text) as List<dynamic>;
  return list
      .map((item) => PublicShop.fromJson(item as Map<String, dynamic>))
      .toList();
}
