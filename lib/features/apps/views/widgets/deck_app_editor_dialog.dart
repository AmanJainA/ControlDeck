import 'package:flutter/material.dart';

import '../../models/deck_app.dart';

/// Reusable form component for creating or editing a launcher shortcut.
/// It returns the edited model; persistence remains the controller's job.
class DeckAppEditorDialog extends StatefulWidget {
  const DeckAppEditorDialog({
    super.key,
    required this.categories,
    this.initialApp,
    this.nextSortOrder = 0,
  });

  final List<String> categories;
  final DeckApp? initialApp;
  final int nextSortOrder;

  @override
  State<DeckAppEditorDialog> createState() => _DeckAppEditorDialogState();
}

class _DeckAppEditorDialogState extends State<DeckAppEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late String _category;
  late String _icon;

  static const _icons = <String, String>{
    'apps': 'Apps',
    'lifehub': 'LifeHub',
    'notes': 'Notes',
    'railways': 'Railways',
    'interview': 'Interview',
    'portfolio': 'Portfolio',
    'admin': 'Admin',
    'analytics': 'Analytics',
    'code': 'Code',
  };

  @override
  void initState() {
    super.initState();
    final app = widget.initialApp;
    _name = TextEditingController(text: app?.name ?? '');
    _description = TextEditingController(text: app?.description ?? '');
    _category = app?.category ?? 'Personal';
    _icon = app?.iconKey ?? 'apps';
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final old = widget.initialApp;
    final app = DeckApp(
      id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      description: _description.text.trim(),
      category: _category,
      url: old?.url ?? '',
      adminUrl: old?.adminUrl ?? '',
      iconKey: _icon,
      accentHex: old?.accentHex ?? 0xFF64748B,
      favorite: old?.favorite ?? false,
      sortOrder: old?.sortOrder ?? widget.nextSortOrder,
    );
    Navigator.of(context).pop(app);
  }

  @override
  Widget build(BuildContext context) {
    final old = widget.initialApp;
    final categories = widget.categories.where((item) => item != 'All apps').toList();
    return AlertDialog(
      title: Text(old == null ? 'Add an app workspace' : 'Edit ${old.name}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'App name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: categories.contains(_category) ? _category : 'Other',
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories.map((item) => DropdownMenuItem(
                  value: item, child: Text(item),
                )).toList(),
                onChanged: (value) => setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _icons.containsKey(_icon) ? _icon : 'apps',
                decoration: const InputDecoration(labelText: 'Icon'),
                items: _icons.entries.map((entry) => DropdownMenuItem(
                  value: entry.key, child: Text(entry.value),
                )).toList(),
                onChanged: (value) => setState(() => _icon = value ?? _icon),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save workspace'),
        ),
      ],
    );
  }
}
