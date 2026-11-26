import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'instagram_embed.dart';
import 'instagram_embed_stub.dart' as stub;

final Set<String> _registeredViews = {};

// 웹: 인스타그램 공식 임베드를 iframe으로 표시 (원작자 계정 · 출처가 함께 보임)
class InstagramPost extends StatelessWidget {
  final String url;
  const InstagramPost({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final embedUrl = instagramEmbedUrl(url);
    if (embedUrl == null) return stub.InstagramPost(url: url);

    final viewType = 'instagram-embed-$embedUrl';
    if (_registeredViews.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) => web.HTMLIFrameElement()
          ..src = embedUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%',
      );
    }
    // 게시물 카드가 너무 커지지 않게 폭을 제한 (넘치는 부분은 iframe 안에서 스크롤)
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(height: 540, child: HtmlElementView(viewType: viewType)),
        ),
      ),
    );
  }
}
