import 'package:flutter/material.dart';
import 'shared/widgets/deck_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Native CRUD screens for the management tables used by the Railways repository.
class RailwaysDataManager extends StatefulWidget {
  const RailwaysDataManager({super.key, required this.db, required this.user, required this.table, required this.title, this.embedded = false});
  final SupabaseClient db;
  final Map<String, dynamic> user;
  final String table, title;
  final bool embedded;
  @override State<RailwaysDataManager> createState() => _RailwaysDataManagerState();
}

class _RailwaysDataManagerState extends State<RailwaysDataManager> {
  bool busy = true;
  String? error;
  List<Map<String,dynamic>> rows = [];
  final search = TextEditingController();
  String uploadStatusFilter = '0';

  static const Map<String,List<Map<String,dynamic>>> fields = {
    'main_heading_master': [
      {'key':'headingname','label':'Main Heading'}, {'key':'status','label':'Active'}, {'key':'created_by','label':'Created by'}
    ],
    'menu_master': [
      {'key':'menuname','label':'Menu name'}, {'key':'main_heading_id','label':'Main heading'}, {'key':'status','label':'Active'}, {'key':'created_by','label':'Created by'}
    ],
    'folder_master': [
      {'key':'foldername','label':'Folder name'}, {'key':'main_heading_id','label':'Main heading'}, {'key':'menu_id','label':'Menu'}, {'key':'status','label':'Active'}, {'key':'created_by','label':'Created by'}
    ],
    'user_main_heading_access': [
      {'key':'user_id','label':'User ID'}, {'key':'main_heading_id','label':'Main heading'}, {'key':'created_by','label':'Created by'}
    ],
    'user_menu_access': [
      {'key':'user_id','label':'User ID'}, {'key':'menu_id','label':'Menu'}, {'key':'created_by','label':'Created by'}
    ],
    'users': [
      {'key':'username','label':'Username'}, {'key':'password','label':'Password'}, {'key':'role','label':'Role: admin / subadmin / user'}, {'key':'email','label':'Email'}, {'key':'dept','label':'Department'}, {'key':'project','label':'Project'}, {'key':'menu_access_ids','label':'Menu access IDs (comma separated)'}
    ],
    'work_item_links': [
      {'key':'work_item_id','label':'Work item ID'}, {'key':'datacollection_id','label':'Document ID'}, {'key':'relation_type','label':'Relation type'}, {'key':'created_by','label':'Created by user ID'}
    ],
    'work_items': [
      {'key':'title','label':'Title'}, {'key':'description','label':'Description','multi':true}, {'key':'main_heading_id','label':'Main heading'}, {'key':'menu_id','label':'Menu'}, {'key':'folder_id','label':'Folder ID'}, {'key':'parent_id','label':'Parent task ID'}, {'key':'work_type','label':'Work type'}, {'key':'status','label':'Status: todo / in_progress / done / blocked'}, {'key':'priority','label':'Priority: low / medium / high / urgent'}, {'key':'assigned_to','label':'Assigned user ID'}, {'key':'due_date','label':'Due date YYYY-MM-DD'}, {'key':'sort_order','label':'Sort order'}, {'key':'created_by','label':'Created by user ID'}
    ],
    'datacollection': [
      {'key':'name','label':'Document title'}, {'key':'links','label':'Storage path or URL','multi':true}, {'key':'type','label':'File type'}, {'key':'main_heading_id','label':'Main heading'}, {'key':'menu_id','label':'Menu'}, {'key':'folder_id','label':'Folder ID'}, {'key':'menuname','label':'Menu name'}, {'key':'folder','label':'Folder name'}, {'key':'status','label':'Status: 0 pending, 1 approved, 2 rejected'}, {'key':'remark','label':'Remark','multi':true}, {'key':'uploaded_by','label':'Uploaded by'}, {'key':'source_type','label':'Source type'}
    ],
  };

  @override void initState() { super.initState(); load(); }
  @override void dispose() { search.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { busy = true; error = null; });
    try {
      final data = widget.table == 'user_presence'
          ? await widget.db.from(widget.table).select('*').order('last_seen', ascending: false)
          : await widget.db.from(widget.table).select('*').order('id', ascending: false);
      var loaded = List<Map<String,dynamic>>.from(data);
      if (widget.table == 'datacollection') {
        final headingRows = await widget.db.from('main_heading_master').select('id,headingname');
        final headingNames = {for (final h in headingRows) (h['id'] as num).toInt(): (h['headingname'] ?? '').toString()};
        loaded = loaded.map((row) => {
          ...row,
          if (row['main_heading_id'] != null) 'main_heading_name': headingNames[(row['main_heading_id'] as num).toInt()] ?? 'Unknown heading',
        }).toList();
      }
      if (['menu_master','folder_master'].contains(widget.table)) {
        final headingRows = await widget.db.from('main_heading_master').select('id,headingname');
        final headingNames = {for (final h in headingRows) (h['id'] as num).toInt(): (h['headingname'] ?? '').toString()};
        final menuRows = await widget.db.from('menu_master').select('id,menuname');
        final menuNames = {for (final m in menuRows) (m['id'] as num).toInt(): (m['menuname'] ?? '').toString()};
        loaded = loaded.map((row) => {
          ...row,
          if (row['main_heading_id'] != null) 'main_heading_name': headingNames[(row['main_heading_id'] as num).toInt()] ?? 'Unknown heading',
          if (row['menu_id'] != null) 'menu_name': menuNames[(row['menu_id'] as num).toInt()] ?? 'Unknown menu',
        }).toList();
      }
      if (mounted) setState(() { rows = loaded; busy = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); busy = false; });
    }
  }

  Future<void> edit([Map<String,dynamic>? old]) async {
    final spec = widget.table == 'main_heading_master'
        ? (fields[widget.table] ?? const []).where((f) => f['key'] == 'headingname').toList()
        : fields[widget.table] ?? const [];
    final controllers = <String,TextEditingController>{};
    for (final f in spec) {
      final key = f['key'].toString();
      controllers[key] = TextEditingController(text: old?[key]?.toString() ?? '');
    }
    if (widget.table == 'work_items' && old != null) {
      try {
        final links = await widget.db.from('work_item_links').select('datacollection_id').eq('work_item_id', old['id']);
        controllers['linked_document_ids']?.text = links.map((x) => x['datacollection_id'].toString()).join(', ');
      } catch (_) {}
    }
    if (widget.table == 'users' && old != null) {
      try {
        final access = await widget.db.from('user_menu_access').select('menu_id').eq('user_id', old['id']);
        controllers['menu_access_ids']?.text = access.map((x) => x['menu_id'].toString()).join(', ');
      } catch (_) {}
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
      final requiredKeys = <String, List<String>>{
        'main_heading_master': ['headingname'],
        'menu_master': ['menuname','main_heading_id'],
        'folder_master': ['foldername','main_heading_id','menu_id'],
        'users': ['username','role'],
        'work_items': ['title','main_heading_id','menu_id'],
        'work_item_links': ['work_item_id','datacollection_id'],
        'datacollection': ['name','links'],
        'user_main_heading_access': ['user_id','main_heading_id'],
        'user_menu_access': ['user_id','menu_id'],
      };
      for (final key in requiredKeys[widget.table] ?? const <String>[]) {
        if ((controllers[key]?.text.trim() ?? '').isEmpty) {
          if (mounted) setState(() => error = 'Please fill the required field: $key.');
          for (final c in controllers.values) { c.dispose(); }
          return;
        }
      }
      final payload = <String,dynamic>{};
      for (final f in spec) {
        final key = f['key'].toString();
        final value = controllers[key]!.text.trim();
        if (key == 'linked_document_ids' || key == 'menu_access_ids') continue;
        if (value.isEmpty) { payload[key] = null; continue; }
        final numericKeys = <String>{'main_heading_id','menu_id','folder_id','parent_id','assigned_to','sort_order'};
        if (widget.table == 'work_items') numericKeys.add('created_by');
        if (widget.table == 'work_item_links') numericKeys.addAll({'work_item_id','datacollection_id','created_by'});
        if (widget.table == 'datacollection' && key == 'status') {
          payload[key] = num.tryParse(value);
        } else if (numericKeys.contains(key)) {
          final parsed = num.tryParse(value);
          if (parsed == null) {
            if (mounted) setState(() => error = 'Enter a valid number for ' + f['label'].toString() + '.');
            for (final controller in controllers.values) { controller.dispose(); }
            return;
          }
          payload[key] = parsed;
        } else {
          payload[key] = value;
        }
      }
      setState(() { busy = true; error = null; });
      try {
        dynamic savedId = old?['id'];
        if (widget.table == 'main_heading_master') {
          if (old == null) {
            payload['status'] = '1';
            payload['created_by'] = (widget.user['username'] ?? '').toString();
            payload['created_at'] = DateTime.now().toIso8601String();
          }
          if (old != null) {
            await widget.db.from(widget.table).update(payload).eq('id', old['id']);
          } else {
            await widget.db.from(widget.table).insert(payload);
          }
        } else if (old != null) {
          await widget.db.from(widget.table).update(payload).eq('id', old['id']);
        } else {
          if (widget.table == 'work_items' || widget.table == 'users') {
            final inserted = await widget.db.from(widget.table).insert(payload).select('id').single();
            savedId = inserted['id'];
          } else {
            await widget.db.from(widget.table).insert(payload);
          }
        }
        if (widget.table == 'work_items' && savedId != null) {
          await widget.db.from('work_item_links').delete().eq('work_item_id', savedId);
          final ids = (controllers['linked_document_ids']?.text ?? '').split(',').map((v) => int.tryParse(v.trim())).whereType<int>().toSet().toList();
          if (ids.isNotEmpty) {
            await widget.db.from('work_item_links').insert(ids.map((id) => {
              'work_item_id': savedId,
              'datacollection_id': id,
              'relation_type': 'deliverable',
              'created_by': widget.user['id'],
            }).toList());
          }
        }
        if (widget.table == 'users' && savedId != null) {
          await widget.db.from('user_menu_access').delete().eq('user_id', savedId);
          final menuIds = (controllers['menu_access_ids']?.text ?? '').split(',').map((v) => int.tryParse(v.trim())).whereType<int>().toSet().toList();
          if (menuIds.isNotEmpty) {
            await widget.db.from('user_menu_access').insert(menuIds.map((id) => {
              'user_id': savedId,
              'menu_id': id,
              'created_by': widget.user['id'],
            }).toList());
          }
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
      if (widget.table == 'datacollection') {
        final path = (row['links'] ?? '').toString().trim();
        final sourceType = (row['source_type'] ?? '').toString();
        final uri = Uri.tryParse(path);
        if (sourceType == 'file_upload' && path.isNotEmpty && (uri == null || !uri.hasScheme)) {
          await widget.db.storage.from('documents').remove([path]);
        }
        await widget.db.from('work_item_links').delete().eq('datacollection_id', row['id']);
        await widget.db.from('file_uploads').delete().eq('datacollection_id', row['id']);
      }
      if (widget.table == 'work_items') {
        await widget.db.from('work_item_links').delete().eq('work_item_id', row['id']);
      }
      final primaryKey = widget.table == 'user_presence' ? 'session_id' : 'id';
      await widget.db.from(widget.table).delete().eq(primaryKey, row[primaryKey]);
      await load();
    } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
  }

  bool get readOnly => ['user_presence','login_history','page_activity','file_uploads'].contains(widget.table);

  String formatCreatedAt(dynamic value) {
    final parsed = value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
    if (parsed == null) return '—';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final ampm = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}, $hour:$minute $ampm';
  }

  @override Widget build(BuildContext context) {
    final visibleFields = widget.table == 'datacollection'
        ? const <Map<String,dynamic>>[
            {'key':'uploaded_by','label':'Uploaded By'},
            {'key':'main_heading_id','label':'Main Heading'},
            {'key':'menuname','label':'Menu'},
            {'key':'folder','label':'Folder'},
            {'key':'type','label':'Type'},
            {'key':'source_type','label':'Source'},
            {'key':'status','label':'Status'},
            {'key':'remark','label':'Remark'},
          ]
        : (fields[widget.table] ?? const <Map<String,dynamic>>[]).where((f) => f['key'] != 'password').take(5).toList();
    final filtered = rows.where((r) {
      final matchesSearch = r.values.any((v) => v != null && v.toString().toLowerCase().contains(search.text.toLowerCase()));
      if (!matchesSearch) return false;
      if (widget.table == 'datacollection' && uploadStatusFilter != 'all') return (r['status'] ?? '').toString() == uploadStatusFilter;
      return true;
    }).toList();
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)), title: Text(widget.title), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Column(children: [
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (widget.table == 'datacollection') Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in const [('0', 'Pending'), ('1', 'Approved'), ('2', 'Rejected'), ('all', 'All')])
              ChoiceChip(label: Text(item.$2), selected: uploadStatusFilter == item.$1, onSelected: (_) => setState(() => uploadStatusFilter = item.$1)),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), child: Row(children: [
          Expanded(child: TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'Search records'))),
          const SizedBox(width: 10),
          if (!readOnly) FilledButton.icon(onPressed: () => edit(), icon: const Icon(Icons.add_rounded), label: const Text('Add')),
        ])),
        Expanded(child: busy ? const Center(child: CircularProgressIndicator()) : filtered.isEmpty
          ? const Center(child: DeckEmptyState(title:'No records found',detail:'Try another search or add a new record.',icon:Icons.search_off_rounded))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 18,
                  columns: widget.table == 'main_heading_master'
                      ? const [
                          DataColumn(label: Text('SN')),
                          DataColumn(label: Text('Main Heading')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Created By')),
                          DataColumn(label: Text('Created Date')),
                          DataColumn(label: Text('Action')),
                        ]
                      : [
                          const DataColumn(label: Text('Record')),
                          ...visibleFields.map((f) => DataColumn(label: Text(f['label'].toString()))),
                          const DataColumn(label: Text('Actions')),
                        ],
                  rows: filtered.asMap().entries.map((entry) {
                    final row = entry.value;
                    if (widget.table == 'main_heading_master') {
                      final active = (row['status'] ?? '0').toString() == '1';
                      return DataRow(cells: [
                        DataCell(Text('${entry.key + 1}')),
                        DataCell(SizedBox(width: 190, child: Text((row['headingname'] ?? '—').toString(), maxLines: 2, overflow: TextOverflow.ellipsis))),
                        DataCell(Transform.scale(scale: 0.72, child: Switch.adaptive(value: active, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, onChanged: (value) async {
                          try {
                            await widget.db.from(widget.table).update({'status': value ? '1' : '0'}).eq('id', row['id']);
                            await load();
                          } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
                        }))),
                        DataCell(Text((row['created_by'] ?? '—').toString())),
                        DataCell(SizedBox(width: 170, child: Text(formatCreatedAt(row['created_at']), maxLines: 2))),
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => edit(row)),
                          IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => remove(row)),
                        ])),
                      ]);
                    }
                    final title = row['headingname'] ?? row['menuname'] ?? row['foldername'] ?? row['username'] ?? row['title'] ?? row['name'] ?? row['id'] ?? 'Record';
                    return DataRow(cells: [
                      DataCell(SizedBox(width: 150, child: Text(title.toString(), maxLines: 2, overflow: TextOverflow.ellipsis))),
                      ...visibleFields.map((f) {
                        final key = f['key'].toString();
                        if (key == 'status' && ['menu_master','folder_master'].contains(widget.table)) {
                          final active = (row[key] ?? '0').toString() == '1';
                          return DataCell(Switch(value: active, onChanged: (value) async {
                            try {
                              await widget.db.from(widget.table).update({'status': value ? '1' : '0'}).eq('id', row['id']);
                              await load();
                            } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
                          }));
                        }
                        final displayKey = key == 'main_heading_id' ? 'main_heading_name' : key == 'menu_id' ? 'menu_name' : key;
                        final rawValue = row[displayKey] ?? row[key];
                        final displayValue = key == 'status' && widget.table == 'datacollection'
                            ? (rawValue?.toString() == '0' ? 'Pending' : rawValue?.toString() == '1' ? 'Approved' : rawValue?.toString() == '2' ? 'Rejected' : '—')
                            : (rawValue ?? '—').toString();
                        return DataCell(SizedBox(width: 130, child: Text(displayValue, maxLines: 2, overflow: TextOverflow.ellipsis)));
                      }),
                      DataCell(readOnly ? const Icon(Icons.chevron_right_rounded) : PopupMenuButton<String>(
                        onSelected: (v) { if (v == 'edit') edit(row); if (v == 'delete') remove(row); },
                        itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            )),
      ]))),
    );
  }
}
