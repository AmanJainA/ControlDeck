import 'package:flutter/material.dart';

Widget buildRailwaysEmbed(BuildContext context) => Scaffold(
  appBar: AppBar(
    leading: IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.arrow_back_rounded),
    ),
    title: const Text('Railways'),
  ),
  body: const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('The embedded Railway workspace is supported on iOS, Android and web.'),
    ),
  ),
);
