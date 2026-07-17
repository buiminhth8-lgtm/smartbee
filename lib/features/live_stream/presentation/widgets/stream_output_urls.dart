import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/stream_url_builder.dart';

class StreamOutputUrlsWidget extends StatelessWidget {
  const StreamOutputUrlsWidget({super.key, required this.urls});

  final StreamOutputUrls urls;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('输出地址', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _UrlRow(label: 'WHIP', value: urls.whip),
        _UrlRow(label: 'RTSP', value: urls.rtsp),
        _UrlRow(label: 'RTMP', value: urls.rtmp),
        _UrlRow(label: 'HLS', value: urls.hls),
        _UrlRow(label: 'WebRTC', value: urls.webrtc),
      ],
    );
  }
}

class _UrlRow extends StatelessWidget {
  const _UrlRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(label)),
          Expanded(child: SelectableText(value, maxLines: 1)),
          IconButton(
            tooltip: '复制',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$label 地址已复制')));
              }
            },
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
    );
  }
}
