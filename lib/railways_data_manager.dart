import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Native CRUD screens for the management tables used by the Railways repository.
class RailwaysDataManager extends StatefulWidget {
  const RailwaysDataManager({super.key, required this.db, required this.user, required this.table, required this.title});
  final SupabaseClient db;
  final Map<String, dynamic> user;
  final String table, title;
  @override State<RailwaysDataManager> createState() => _RailwaysDataManagerState();
}

class _RailwaysDataManagerState extends State<RailwaysDataManager> {
  bool busy = true;
  String? error;
  List<Map<String,dynamic>> rows = [];
  final search = TextEditingController();

  static const Map<String,List<Map<String,dynamic>>> fields = {
    'main_heading_master': [
      {'key':'headingname','label':'Heading name'}, {'key':'status','label':'Status (1 active, 0 inactive'}, {'key':'created_by','label':'Created by'}
    ],
    'menu_master': [
      {'key':'menuname','label':'Menu name'}, {'key':'main_heading_id','label':'Main heading ID'}, {'key':'status','label':'Status (1 active, 0 inactive'}, {'key':'created_by','label':'Created by'}
    ],
    'folder_master': [
      {'key':'foldername','label':'Folder name'}, {'key':'main_heading_id','label':'Main heading ID'}, {'key':'menu_id','label':'Menu ID'}, {'key':'status','label':'Status (1 active, 0 inactive'}, {'key':'created_by','label':'Created by'}
    ],
    'user_main_heading_access': [
      {'key':'user_id','label':'User ID'}, {'key':'main_heading_id','label':'Main heading ID'}, {'key':'created_by','label':'Created by'}
    ],
    'user_menu_access': [
      {'key':'user_id','label':'User ID'}, {'key':'menu_id','label':'Menu ID'}, {'key':'created_by','label':'Created by'}
    ],
    'users': [
      {'key':'username','label':'Username'}, {'key':'password','label':'Password'}, {'key':'role','label':'Role: admin / subadmin / user'}, {'key':'email','label':'Email'}, {'key':'dept','label':'Department'}, {'key':'project','label':'Project'}
    ],
    'work_items': [
      {'key':'title','label':'Title'}, {'key':'description','label':'Description','multi':true}, {'key':'main_heading_id','label':'Main heading ID'}, {'key':'menu_id','label':'Menu ID'}, {'key':'folder_id','label':'Folder ID'}, {'key':'parent_id','label':'Parent task ID'}, {'key':'work_type','label':'Work type'}, {'key':'status','label':'Status: todo / in_progress / done / blocked'}, {'key':'priority','label':'Priority: low / medium / high / urgent'}, {'key':'assigned_to','label':'Assigned user ID'}, {'key':'due_date','label':'Due date YYYY-MM-DD'}, {'key':'sort_order','label':'Sort order'}
    ],
    'datacollection': [
      {'key':'name','label':'Document title'}, {'key':'links','label':'Storage path or URL','multi':true}, {'key':'type','label':'File type'}, {'key':'main_heading_id','label':'Main heading ID'}, {'key':'menu_id','label':'Menu ID'}, {'key':'folder_id','label':'Folder ID'}, {'key':'menuname','label':'Menu name'}, {'key':'folder','label':'Folder name'}, {'key':'status','label':'Status: 0 pending, 1 approved, 2 rejected'}, {'key':'remark','label':'Remark','multi':true}, {'key':'uploaded_by','label':'Uploaded by'}, {'key':'source_type','label':'Source type'}
    ],
  };

  @override void initState() { super.initState(); load(); }
  @override void dispose() { search.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { busy = true; error = null; });
    try {
      final data = await widget.db.from(widget.table).select('*').order('id', ascending: false);
      if (mounted) setState(() { rows = List<Map<String,dynamic>>.from(data); busy = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); busy = false; });
    }
  }

  Future<void> edit([Map<String,dynamic>? old]) async {
    final spec = fields[widget.table] ?? const [];
    final controllers = <String,TextEditingController>{};
    for (final f in spec) {
      final key = f['key'].toString();
      controllers[key] = TextEditingController(text: old?[key]?.toString() ?? '');
    }
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text((old == null ? 'Add ' : 'Edit ') + widget.title),
      content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final f in spec) Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(
          controller: controllers[f['key'].toString()],
          minLines: f['multi'] == true ? 2 : 1,
          maxLines: f['multi'] == true ? 4 : 1,
          decoration: InputDecoration(labelText: f['label'].toString()),
        )),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
    ));
    if (accepted == true) {
      final payload = <String,dynamic>{};
      for (final f in spec) {
        final key = f['key'].toString();
        final value = controllers[key]!.text.trim();
        if (value.isEmpty) { payload[key] = null; continue; }
        if (['main_heading_id','menu_id','folder_id','parent_id','assigned_to','sort_order','status'].contains(key) && widget.table != 'users' && widget.table != 'main_heading_master' && widget.table != 'menu_master' && widget.table != 'folder_master') {
          payload[key] = num.tryParse(value);
        } else if (['main_heading_id','menu_id','folder_id','parent_id','assigned_to','sort_order'].contains(key)) {
          payload[key] = num.tryParse(value);
        } else {
          payload[key] = value;
        }
      }
      setState(() { busy = true; error = null; });
      try {
        if (old != null) {
          await widget.db.from(widget.table).update(payload).eq('id', old['id']);
        } else {
          await widget.db.from(widget.table).insert(payload);
        }
        await load();
      } catch (e) {
        if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); busy = false; });
      }
    }
    for (final c in controllers.values) { c.dispose(); }
  }

  Future<void> remove(Map<String,dynamic> row) async {
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete record?'),
      content: Text('This permanently removes this ' + widget.title.toLowerCase() + ' record.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (accepted != true) return;
    try {
      await widget.db.from(widget.table).delete().eq('id', row['id']);
      await load();
    } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
  }

  bool get readOnly => ['user_presence','login_history','page_activity','file_uploads'].contains(widget.table);

  @override Widget build(BuildContext context) {
    final filtered = rows.where((r) => r.values.any((v) => v != null && v.toString().toLowerCase().contains(search.text.toLowerCase()))).toList();
    return Scaffold(
      appBar: AppBar(leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)), title: Text(widget.title), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Column(children: [
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6), child: Row(children: [
          Expanded(child: TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'Search records'))),
          const SizedBox(width: 10),
          if (!readOnly) FilledButton.icon(onPressed: () => edit(), icon: const Icon(Icons.add_rounded), label: const Text('Add')),
        ])),
        Expanded(child: busy ? const Center(child: CircularProgressIndicator()) : filtered.isEmpty
          ? const Center(child: Text('No records found.'))
          : ListView.builder(padding: const EdgeInsets.all(12), itemCount: filtered.length, itemBuilder: (ctx, i) {
            final row = filtered[i];
            final title = row['headingname'] ?? row['menuname'] ?? row['foldername'] ?? row['username'] ?? row['title'] ?? row['name'] ?? row['id'] ?? 'Record';
            final summary = row.entries.where((e) => e.key != 'id' && e.key != 'password' && e.value != null && e.value.toString().isNotEmpty).take(5).map((e) => e.key.replaceAll('_', ' ') + ': ' + e.value.toString()).join(' • ');
            return Card(child: ListTile(
              title: Text(title.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(summary, maxLines: 3, overflow: TextOverflow.ellipsis),
              trailing: readOnly ? const Icon(Icons.chevron_right_rounded) : PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') edit(row); if (v == 'delete') remove(row); }, itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ]),
            ));
          })),
      ]))),
    );
  }
}
