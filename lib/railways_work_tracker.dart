import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef WorkDocumentOpener = Future<void> Function(Map<String, dynamic> document);

class RailwaysWorkTracker extends StatefulWidget {
  const RailwaysWorkTracker({super.key, required this.db, required this.user, required this.onOpenDocument});
  final SupabaseClient db;
  final Map<String, dynamic> user;
  final WorkDocumentOpener onOpenDocument;

  @override
  State<RailwaysWorkTracker> createState() => _RailwaysWorkTrackerState();
}

class _RailwaysWorkTrackerState extends State<RailwaysWorkTracker> {
  static const statuses = {'todo': 'To Do', 'in_progress': 'In Progress', 'done': 'Done', 'blocked': 'Blocked'};
  static const priorities = {'low': 'Low', 'medium': 'Medium', 'high': 'High', 'urgent': 'Urgent'};
  static const workTypes = <Map<String, String>>[
    {'value': 'study', 'label': 'Study / Report'}, {'value': 'letter', 'label': 'Letter'},
    {'value': 'meeting', 'label': 'Meeting'}, {'value': 'ppt', 'label': 'PPT / Presentation'},
    {'value': 'data_requirement', 'label': 'Data Requirement'}, {'value': 'acceptance', 'label': 'Acceptance / Response'},
    {'value': 'format', 'label': 'Format / Template'}, {'value': 'analysis', 'label': 'Analysis'},
    {'value': 'todo', 'label': 'General Todo'}, {'value': 'other', 'label': 'Other'},
  ];
  List<Map<String, dynamic>> headings = [], menus = [], folders = [], documents = [], items = [];
  bool loading = true, saving = false;
  String? error;
  String filterHeading = 'all', filterMenu = 'all', filterStatus = 'all', searchText = '';
  bool get isAdmin => (widget.user['role'] ?? '').toString().toLowerCase() == 'admin';
  int? get userId => (widget.user['id'] as num?)?.toInt();

  @override
  void initState() { super.initState(); loadAll(); }

  Future<void> loadAll() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final rawH = await widget.db.from('main_heading_master').select('id,headingname,status').eq('status', '1').order('id');
      var hs = List<Map<String, dynamic>>.from(rawH);
      if (!isAdmin) {
        if (userId == null) { hs = []; } else {
          final a = await widget.db.from('user_main_heading_access').select('main_heading_id').eq('user_id', userId!);
          final ids = a.map((r) => (r['main_heading_id'] as num).toInt()).toSet();
          hs = hs.where((h) => ids.contains((h['id'] as num).toInt())).toList();
        }
      }
      final headingIds = hs.map((h) => (h['id'] as num).toInt()).toList();
      var ms = <Map<String, dynamic>>[];
      if (headingIds.isNotEmpty) {
        final raw = await widget.db.from('menu_master').select('id,menuname,main_heading_id,status').eq('status', '1').inFilter('main_heading_id', headingIds).order('id');
        ms = List<Map<String, dynamic>>.from(raw);
      }
      if (!isAdmin) {
        final a = await widget.db.from('user_menu_access').select('menu_id').eq('user_id', userId ?? -1);
        final ids = a.map((r) => (r['menu_id'] as num).toInt()).toSet();
        ms = ms.where((m) => ids.contains((m['id'] as num).toInt())).toList();
      }
      final menuIds = ms.map((m) => (m['id'] as num).toInt()).toList();
      var fs = <Map<String, dynamic>>[];
      if (menuIds.isNotEmpty) {
        final raw = await widget.db.from('folder_master').select('id,foldername,main_heading_id,menu_id,status').eq('status', '1').inFilter('menu_id', menuIds).order('id');
        fs = List<Map<String, dynamic>>.from(raw);
      }
      var docs = <Map<String, dynamic>>[];
      if (headingIds.isNotEmpty) {
        final raw = await widget.db.from('datacollection').select('id,name,links,type,status,main_heading_id,menu_id,folder_id,menuname,folder,source_type').eq('status', 1).inFilter('main_heading_id', headingIds).order('id', ascending: false);
        final allowed = ms.map((m) => (m['id'] as num).toInt()).toSet();
        docs = List<Map<String, dynamic>>.from(raw).where((d) => allowed.contains((d['menu_id'] as num?)?.toInt())).toList();
      }
      final rawItems = await widget.db.from('work_items').select('*').order('main_heading_id').order('menu_id').order('sort_order').order('id');
      final rows = List<Map<String, dynamic>>.from(rawItems);
      final ids = rows.map((r) => r['id']).whereType<num>().map((n) => n.toInt()).toList();
      var links = <Map<String, dynamic>>[];
      if (ids.isNotEmpty) {
        final raw = await widget.db.from('work_item_links').select('id,work_item_id,datacollection_id,relation_type').inFilter('work_item_id', ids);
        links = List<Map<String, dynamic>>.from(raw);
      }
      final enriched = rows.map((r) => <String, dynamic>{...r, 'links': links.where((l) => (l['work_item_id'] as num?)?.toInt() == (r['id'] as num?)?.toInt()).toList()}).toList();
      if (!mounted) return;
      setState(() { headings = hs; menus = ms; folders = fs; documents = docs; items = enriched; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get visibleItems {
    final hids = headings.map((h) => (h['id'] as num).toInt()).toSet();
    final mids = menus.map((m) => (m['id'] as num).toInt()).toSet();
    return items.where((x) {
      final h = (x['main_heading_id'] as num?)?.toInt(), m = (x['menu_id'] as num?)?.toInt();
      if (h == null || m == null || !hids.contains(h) || !mids.contains(m)) return false;
      if (filterHeading != 'all' && h != int.tryParse(filterHeading)) return false;
      if (filterMenu != 'all' && m != int.tryParse(filterMenu)) return false;
      if (filterStatus != 'all' && x['status'] != filterStatus) return false;
      final q = searchText.trim().toLowerCase();
      if (q.isNotEmpty && !(x['title'].toString() + ' ' + (x['description'] ?? '').toString() + ' ' + (x['work_type'] ?? '').toString()).toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  String headingName(dynamic id) { for (final h in headings) { if (h['id'].toString() == id.toString()) return (h['headingname'] ?? '').toString(); } return 'Heading #$id'; }
  String menuName(dynamic id) { for (final m in menus) { if (m['id'].toString() == id.toString()) return (m['menuname'] ?? '').toString(); } return 'Menu #$id'; }
  String folderName(dynamic id) { for (final f in folders) { if (f['id'].toString() == id.toString()) return (f['foldername'] ?? '').toString(); } return ''; }

  List<Map<String, dynamic>> get treeItems {
    final rows = visibleItems;
    final children = <int, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      children.putIfAbsent((row['parent_id'] as num?)?.toInt() ?? 0, () => []).add(row);
    }
    final output = <Map<String, dynamic>>[];
    final seen = <int>{};
    void walk(int parent, int depth) {
      for (final row in children[parent] ?? const <Map<String, dynamic>>[]) {
        final id = (row['id'] as num).toInt();
        if (!seen.add(id)) continue;
        output.add({...row, '_depth': depth});
        walk(id, depth + 1);
      }
    }
    walk(0, 0);
    for (final row in rows) {
      final id = (row['id'] as num).toInt();
      if (seen.add(id)) output.add({...row, '_depth': 0});
    }
    return output;
  }

  Future<void> editItem([Map<String, dynamic>? old]) async {
    final title = TextEditingController(text: (old?['title'] ?? '').toString());
    final description = TextEditingController(text: (old?['description'] ?? '').toString());
    final fileSearch = TextEditingController();
    String hid = (old?['main_heading_id'] ?? (headings.isNotEmpty ? headings.first['id'] : '')).toString();
    String mid = (old?['menu_id'] ?? '').toString(), fid = (old?['folder_id'] ?? '').toString(), pid = (old?['parent_id'] ?? '').toString();
    String type = (old?['work_type'] ?? 'todo').toString(), status = (old?['status'] ?? 'todo').toString(), priority = (old?['priority'] ?? 'medium').toString();
    DateTime? due = DateTime.tryParse((old?['due_date'] ?? '').toString());
    final linked = <int>{for (final l in (old?['links'] as List? ?? const []) as List) if (l['datacollection_id'] is num) (l['datacollection_id'] as num).toInt()};
    String fileQuery = '';
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (dc) => StatefulBuilder(builder: (context, refresh) {
      final hm = menus.where((m) => m['main_heading_id'].toString() == hid).toList();
      if (mid.isNotEmpty && !hm.any((m) => m['id'].toString() == mid)) mid = '';
      final mf = folders.where((f) => f['main_heading_id'].toString() == hid && f['menu_id'].toString() == mid).toList();
      if (fid.isNotEmpty && !mf.any((f) => f['id'].toString() == fid)) fid = '';
      final parents = items.where((x) => x['main_heading_id'].toString() == hid && x['menu_id'].toString() == mid && x['id'].toString() != (old?['id'] ?? '').toString()).toList();
      final related = documents.where((d) => d['main_heading_id'].toString() == hid && ((d['name'] ?? '').toString() + ' ' + (d['menuname'] ?? '').toString() + ' ' + (d['folder'] ?? '').toString() + ' ' + (d['type'] ?? '').toString()).toLowerCase().contains(fileQuery.toLowerCase())).toList();
      const border = OutlineInputBorder();
      InputDecoration dec(String label) => InputDecoration(labelText: label, border: border, isDense: true);
      return AlertDialog(
        title: Text(old == null ? 'Add Work / Todo' : 'Edit Work / Todo'),
        content: SizedBox(width: 650, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: headings.any((h) => h['id'].toString() == hid) ? hid : null, decoration: dec('Main Heading'), items: headings.map((h) => DropdownMenuItem(value: h['id'].toString(), child: Text((h['headingname'] ?? '').toString(), overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => refresh(() { hid = v ?? ''; mid = ''; fid = ''; pid = ''; })),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: hm.any((m) => m['id'].toString() == mid) ? mid : null, decoration: dec('Menu'), items: hm.map((m) => DropdownMenuItem(value: m['id'].toString(), child: Text((m['menuname'] ?? '').toString(), overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => refresh(() { mid = v ?? ''; fid = ''; pid = ''; })),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: mf.any((f) => f['id'].toString() == fid) ? fid : '', decoration: dec('Folder (optional)'), items: [const DropdownMenuItem(value: '', child: Text('No specific folder')), ...mf.map((f) => DropdownMenuItem(value: f['id'].toString(), child: Text((f['foldername'] ?? '').toString(), overflow: TextOverflow.ellipsis)))], onChanged: (v) => refresh(() => fid = v ?? '')),
          const SizedBox(height: 10),
          TextField(controller: title, decoration: dec('Work / Todo title')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: workTypes.any((w) => w['value'] == type) ? type : 'todo', decoration: dec('Work Type'), items: workTypes.map((w) => DropdownMenuItem(value: w['value'], child: Text(w['label']!))).toList(), onChanged: (v) => refresh(() => type = v ?? 'todo')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: parents.any((x) => x['id'].toString() == pid) ? pid : '', decoration: dec('Parent Work / Todo (optional)'), items: [const DropdownMenuItem(value: '', child: Text('Top-level Work / Todo')), ...parents.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text((x['title'] ?? '').toString(), overflow: TextOverflow.ellipsis)))], onChanged: (v) => refresh(() => pid = v ?? '')),
          const SizedBox(height: 10),
          TextField(controller: description, minLines: 2, maxLines: 4, decoration: dec('Explanation / Description')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(value: statuses.containsKey(status) ? status : 'todo', decoration: dec('Status'), items: statuses.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) => refresh(() => status = v ?? 'todo'))),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<String>(value: priorities.containsKey(priority) ? priority : 'medium', decoration: dec('Priority'), items: priorities.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) => refresh(() => priority = v ?? 'medium'))),
          ]),
          Row(children: [
            Expanded(child: Text(due == null ? 'No due date' : 'Due ' + due!.day.toString() + '/' + due!.month.toString() + '/' + due!.year.toString())),
            TextButton.icon(onPressed: () async { final picked = await showDatePicker(context: context, initialDate: due ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100)); if (picked != null) refresh(() => due = picked); }, icon: const Icon(Icons.calendar_month_outlined), label: const Text('Due date')),
            if (due != null) IconButton(onPressed: () => refresh(() => due = null), icon: const Icon(Icons.close)),
          ]),
          const Divider(),
          Row(children: [const Expanded(child: Text('Related Files — select multiple', style: TextStyle(fontWeight: FontWeight.w700))), Text(linked.length.toString() + ' selected')]),
          const SizedBox(height: 8),
          TextField(controller: fileSearch, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search files', border: border, isDense: true), onChanged: (v) => refresh(() => fileQuery = v)),
          const SizedBox(height: 8),
          SizedBox(height: 180, child: ListView.builder(itemCount: related.length, itemBuilder: (context, index) {
            final doc = related[index], id = (doc['id'] as num).toInt();
            return CheckboxListTile(dense: true, value: linked.contains(id), title: Text((doc['name'] ?? 'Document').toString(), maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text((doc['menuname'] ?? 'Menu').toString() + ((doc['folder'] ?? '').toString().isEmpty ? '' : ' • ' + doc['folder'].toString()), maxLines: 1, overflow: TextOverflow.ellipsis), onChanged: (v) => refresh(() { if (v == true) { linked.add(id); } else { linked.remove(id); } }));
          })),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (hid.isEmpty || mid.isEmpty || title.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Main Heading, Menu and Work / Todo title are required.')));
              return;
            }
            Navigator.pop(dc, {
              'main_heading_id': int.parse(hid), 'menu_id': int.parse(mid), 'folder_id': fid.isEmpty ? null : int.parse(fid),
              'parent_id': pid.isEmpty ? null : int.parse(pid), 'title': title.text.trim(),
              'description': description.text.trim().isEmpty ? null : description.text.trim(), 'work_type': type,
              'status': status, 'priority': priority,
              'due_date': due == null ? null : due!.year.toString().padLeft(4, '0') + '-' + due!.month.toString().padLeft(2, '0') + '-' + due!.day.toString().padLeft(2, '0'),
              'linked_ids': linked.toList(),
            });
          }, child: Text(old == null ? 'Create Work / Todo' : 'Save Changes')),
        ],
      );
    }));
    title.dispose(); description.dispose(); fileSearch.dispose();
    if (result != null && mounted) await saveItem(result, old);
  }

  Future<void> saveItem(Map<String, dynamic> form, Map<String, dynamic>? old) async {
    setState(() { saving = true; error = null; });
    try {
      final payload = <String, dynamic>{
        'main_heading_id': form['main_heading_id'], 'menu_id': form['menu_id'], 'folder_id': form['folder_id'],
        'parent_id': form['parent_id'], 'title': form['title'], 'description': form['description'],
        'work_type': form['work_type'], 'status': form['status'], 'priority': form['priority'], 'due_date': form['due_date'],
      };
      int id;
      if (old != null) {
        id = (old['id'] as num).toInt();
        await widget.db.from('work_items').update(payload).eq('id', id);
      } else {
        payload['created_by'] = userId;
        final inserted = await widget.db.from('work_items').insert(payload).select('id').single();
        id = (inserted['id'] as num).toInt();
      }
      await widget.db.from('work_item_links').delete().eq('work_item_id', id);
      final linkedIds = List<dynamic>.from(form['linked_ids'] as List? ?? const []);
      if (linkedIds.isNotEmpty) {
        await widget.db.from('work_item_links').insert(linkedIds.map((v) => {'work_item_id': id, 'datacollection_id': (v as num).toInt(), 'relation_type': 'deliverable', 'created_by': userId}).toList());
      }
      await loadAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(old == null ? 'Work / Todo created.' : 'Work / Todo updated.')));
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> deleteItem(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Work / Todo?'), content: Text('Delete "' + (item['title'] ?? '').toString() + '" and its linked file references?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (ok != true) return;
    try {
      final id = (item['id'] as num).toInt();
      await widget.db.from('work_item_links').delete().eq('work_item_id', id);
      await widget.db.from('work_items').delete().eq('id', id);
      await loadAll();
    } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
  }

  @override
  Widget build(BuildContext context) {
    final filteredMenus = filterHeading == 'all' ? menus : menus.where((m) => m['main_heading_id'].toString() == filterHeading).toList();
    final rows = treeItems;
    return Scaffold(
      appBar: AppBar(title: const Text('Work Tracker / Todo'), actions: [IconButton(tooltip: 'Refresh', onPressed: loading ? null : loadAll, icon: const Icon(Icons.refresh_rounded))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: loading || saving || headings.isEmpty ? null : () => editItem(), icon: const Icon(Icons.add_rounded), label: const Text('Add Work / Todo')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200), child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Connected Work Register', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4), const Text('Organize work by Main Heading, Menu and Folder. Create parent/child tasks and connect multiple deliverable files.'),
          const SizedBox(height: 14),
          TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'Search work and description', border: OutlineInputBorder(), isDense: true), onChanged: (v) => setState(() => searchText = v)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: filterHeading, decoration: const InputDecoration(labelText: 'Main Heading', border: OutlineInputBorder(), isDense: true), items: [const DropdownMenuItem(value: 'all', child: Text('All Main Headings')), ...headings.map((h) => DropdownMenuItem(value: h['id'].toString(), child: Text((h['headingname'] ?? '').toString(), overflow: TextOverflow.ellipsis)))], onChanged: (v) => setState(() { filterHeading = v ?? 'all'; filterMenu = 'all'; })),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: filterMenu, decoration: const InputDecoration(labelText: 'Menu', border: OutlineInputBorder(), isDense: true), items: [const DropdownMenuItem(value: 'all', child: Text('All Menus')), ...filteredMenus.map((m) => DropdownMenuItem(value: m['id'].toString(), child: Text((m['menuname'] ?? '').toString(), overflow: TextOverflow.ellipsis)))], onChanged: (v) => setState(() => filterMenu = v ?? 'all')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: filterStatus, decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true), items: [const DropdownMenuItem(value: 'all', child: Text('All Statuses')), ...statuses.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))], onChanged: (v) => setState(() => filterStatus = v ?? 'all')),
        ]))),
        if (error != null) Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(14), child: Text(error!))),
        if (loading || saving) const LinearProgressIndicator(),
        if (!loading && rows.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No work items found for the selected filters.'))),
        for (final row in rows) _workCard(row),
      ]))),
    );
  }

  Widget _workCard(Map<String, dynamic> row) {
    final depth = (row['_depth'] as int?) ?? 0;
    final status = (row['status'] ?? 'todo').toString(), priority = (row['priority'] ?? 'medium').toString();
    var type = (row['work_type'] ?? 'General Todo').toString();
    for (final workType in workTypes) { if (workType['value'] == row['work_type']) { type = workType['label']!; break; } }
    final linked = (row['links'] as List? ?? const []).cast<Map<String, dynamic>>();
    final docsById = {for (final d in documents) (d['id'] as num).toInt(): d};
    final due = DateTime.tryParse((row['due_date'] ?? '').toString());
    Color color(String s) => s == 'done' ? Colors.green : s == 'in_progress' ? Colors.blue : s == 'blocked' ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.outline;
    Widget chip(String text, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)));
    return Padding(padding: EdgeInsets.only(left: (depth * 12).clamp(0, 48).toDouble(), bottom: 8), child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(depth > 0 ? Icons.subdirectory_arrow_right_rounded : Icons.task_alt_rounded, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((row['title'] ?? 'Untitled').toString(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          if ((row['description'] ?? '').toString().trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text(row['description'].toString())),
        ])),
        PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') editItem(row); if (v == 'delete') deleteItem(row); }, itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete')),
        ]),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 7, runSpacing: 7, children: [
        chip(statuses[status] ?? status, color(status)),
        chip(priorities[priority] ?? priority, priority == 'urgent' ? Colors.deepOrange : priority == 'high' ? Colors.orange : Theme.of(context).colorScheme.secondary),
        chip(type, Theme.of(context).colorScheme.primary),
      ]),
      const SizedBox(height: 9),
      Text(headingName(row['main_heading_id']) + '  ›  ' + menuName(row['menu_id']) + (row['folder_id'] == null ? '' : '  ›  ' + folderName(row['folder_id'])), style: Theme.of(context).textTheme.bodySmall),
      if (due != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text('Due ' + due.day.toString() + ' ' + const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][due.month - 1] + ' ' + due.year.toString(), style: TextStyle(color: due.isBefore(DateTime.now()) && status != 'done' ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurfaceVariant))),
      const SizedBox(height: 8),
      if (linked.isEmpty) Text('No files linked', style: Theme.of(context).textTheme.bodySmall)
      else Wrap(spacing: 6, runSpacing: 6, children: [
        for (final link in linked)
          if (docsById[(link['datacollection_id'] as num?)?.toInt()] != null)
            ActionChip(avatar: const Icon(Icons.description_outlined, size: 17), label: Text((docsById[(link['datacollection_id'] as num).toInt()]!['name'] ?? 'Document').toString(), overflow: TextOverflow.ellipsis), onPressed: () => widget.onOpenDocument(docsById[(link['datacollection_id'] as num).toInt()]!)),
      ]),
    ]))));
  }
}
