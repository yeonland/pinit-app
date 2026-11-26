import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'instagram_embed.dart';
import 'instagram_embed_stub.dart' as stub;

// 웹: 인스타그램 공식 임베드를 iframe으로 표시 (원작자 계정 · 출처가 함께 보임)
class InstagramPost extends StatefulWidget {
  final String url;
  const InstagramPost({super.key, required this.url});

  @override
  State<InstagramPost> createState() => _InstagramPostState();
}

class _InstagramPostState extends State<InstagramPost> {
  bool _loaded = false; // iframe 문서를 다 불러오기 전까지 로딩 표시

  @override
  Widget build(BuildContext context) {
    final embedUrl = instagramEmbedUrl(widget.url);
    if (embedUrl == null) return stub.InstagramPost(url: widget.url);

    // 게시물 카드가 너무 커지지 않게 폭을 제한 (넘치는 부분은 iframe 안에서 스크롤)
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 540,
            child: Stack(
              fit: StackFit.expand,
              children: [
                HtmlElementView.fromTagName(
                  tagName: 'iframe',
                  onElementCreated: (Object element) {
                    final iframe = element as web.HTMLIFrameElement
                      ..src = embedUrl
                      ..style.border = 'none'
                      ..style.width = '100%'
                      ..style.height = '100%';
                    iframe.addEventListener(
                      'load',
                      ((web.Event _) {
                        if (mounted) setState(() => _loaded = true);
                      }).toJS,
                    );
                  },
                ),
                if (!_loaded) const _LoadingCover(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingCover extends StatelessWidget {
  const _LoadingCover();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).cardColor,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          SizedBox(height: 12),
          Text('인스타그램 게시물 불러오는 중…', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}
