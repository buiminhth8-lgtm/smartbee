import 'package:flutter/material.dart';

import '../../domain/stream_server_config.dart';

class ServerConfigPanel extends StatefulWidget {
  const ServerConfigPanel({
    super.key,
    required this.config,
    required this.onChanged,
  });

  final StreamServerConfig config;
  final ValueChanged<StreamServerConfig> onChanged;

  @override
  State<ServerConfigPanel> createState() => _ServerConfigPanelState();
}

class _ServerConfigPanelState extends State<ServerConfigPanel> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _streamController;
  late final TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.config.host);
    _portController = TextEditingController(
      text: '${widget.config.webrtcPort}',
    );
    _streamController = TextEditingController(text: widget.config.streamName);
    _tokenController = TextEditingController(text: widget.config.bearerToken);
  }

  @override
  void didUpdateWidget(covariant ServerConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.host != widget.config.host) {
      _hostController.text = widget.config.host;
    }
    if (oldWidget.config.webrtcPort != widget.config.webrtcPort) {
      _portController.text = '${widget.config.webrtcPort}';
    }
    if (oldWidget.config.streamName != widget.config.streamName) {
      _streamController.text = widget.config.streamName;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _streamController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _emit({bool? useHttps}) {
    widget.onChanged(
      widget.config.copyWith(
        host: _hostController.text.trim(),
        webrtcPort:
            int.tryParse(_portController.text.trim()) ??
            widget.config.webrtcPort,
        streamName: _streamController.text.trim(),
        useHttps: useHttps ?? widget.config.useHttps,
        bearerToken: _tokenController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '服务器配置',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(labelText: '服务器地址'),
                  onChanged: (_) => _emit(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _portController,
                  decoration: const InputDecoration(labelText: '端口'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _emit(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _streamController,
            decoration: const InputDecoration(labelText: '流名称'),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(labelText: 'Bearer Token'),
                  obscureText: true,
                  onChanged: (_) => _emit(),
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                selected: widget.config.useHttps,
                label: Text(widget.config.useHttps ? 'HTTPS' : 'HTTP'),
                onSelected: (selected) => _emit(useHttps: selected),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
