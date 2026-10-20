import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

const _railwaysUrl = 'https://amanjaina.github.io/Railways/';
const _viewType = 'controldeck-railways-portal-frame';
bool _registered = false;

Widget buildRailwaysEmbed(BuildContext context) {
  if (!_registered) {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final frame = web.HTMLIFrameElement()
        ..src = _railwaysUrl
        ..title = 'Railways workspace'
        ..allow = 'clipboard-read; clipboard-write; fullscreen'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block';
      return frame;
    });
    _registered = true;
  }

  return Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back to ControlDeck',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Railways'),
      actions: [
        IconButton(
          tooltip: 'Reload Railway workspace',
          onPressed: () {
            // Rebuild the iframe view to reload the live workspace.
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const _RailwaysWebReload()),
            );
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: const SizedBox.expand(child: HtmlElementView(viewType: _viewType)),
  );
}

class _RailwaysWebReload extends StatelessWidget {
  const _RailwaysWebReload();

  @override
  Widget build(BuildContext context) => buildRailwaysEmbed(context);
}
