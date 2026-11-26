import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pinit_colors.dart';

// 웹이 아닌 곳(앱 · 테스트)에서는 임베드 대신 원본 게시물을 여는 버튼
// shortcut: 앱(iOS/Android)에서 임베드까지 보이려면 webview 패키지 필요
class InstagramPost extends StatelessWidget {
  final String url;
  const InstagramPost({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(foregroundColor: instagramPink),
      icon: const Icon(Icons.open_in_new, size: 18),
      label: const Text('인스타그램에서 원본 보기'),
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
