import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _railwaysUrl = 'https://amanjaina.github.io/Railways/';

Widget buildRailwaysEmbed(BuildContext context) => _RailwaysMobileEmbed();

class _RailwaysMobileEmbed extends StatefulWidget {
  @override
  State<_RailwaysMobileEmbed> createState() => _RailwaysMobileEmbedState();
}

class _RailwaysMobileEmbedState extends State<_RailwaysMobileEmbed> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _canGoBack = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F6F3))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() { _loading = true; _error = null; });
        },
        onPageFinished: (_) async {
          final canGoBack = await _controller.canGoBack();
          if (mounted) setState(() { _loading = false; _canGoBack = canGoBack; });
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() { _loading = false; _error = error.description; });
          }
        },
      ))
      ..loadRequest(Uri.parse(_railwaysUrl));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_canGoBack,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _canGoBack) _controller.goBack();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () async {
            if (await _controller.canGoBack()) {
              await _controller.goBack();
            } else if (context.mounted) {
              Navigator.of(context).maybePop();
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Railways'),
        actions: [
          IconButton(
            tooltip: 'Reload Railway workspace',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _controller)),
          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 42),
                    const SizedBox(height: 12),
                    const Text('Railways could not be loaded', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _controller.loadRequest(Uri.parse(_railwaysUrl)),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
