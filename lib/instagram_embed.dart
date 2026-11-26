// 인스타그램 게시물 공식 임베드 (웹: iframe / 그 외: 원본 열기 버튼)
export 'instagram_embed_stub.dart' if (dart.library.js_interop) 'instagram_embed_web.dart';

/// 게시물 링크 → 공식 임베드 주소 (추적용 쿼리는 버림). 게시물 링크가 아니면 null
String? instagramEmbedUrl(String postUrl) {
  final match = RegExp(r'instagram\.com/(p|reel)/([A-Za-z0-9_-]+)').firstMatch(postUrl);
  if (match == null) return null;
  return 'https://www.instagram.com/${match[1]}/${match[2]}/embed/';
}
