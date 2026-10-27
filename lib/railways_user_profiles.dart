import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Native equivalent of Railways Admin > User Profiles.
class RailwaysUserProfiles extends StatefulWidget {
  const RailwaysUserProfiles({super.key, required this.db, required this.user});
  final SupabaseClient db;
  final Map<String, dynamic> user;

  @override
  State<RailwaysUserProfiles> createState() => _RailwaysUserProfilesState();
}

class _RailwaysUserProfilesState extends State<RailwaysUserProfiles> {
  bool busy = true, saving = false;
  String search = '', roleFilter = 'all';
  int page = 1, pageSize = 10;
  String? error, notice;
  List<Map<String, dynamic>> users = [], headings = [], menus = [];
  Map<int, List<String>> headingNames = {}, menuNames = {};
  final formKey = GlobalKey<FormState>();
  final username = TextEditingController(), password = TextEditingController(),
      email = TextEditingController(), dept = TextEditingController();
  String role = 'user';
  int? editId;
  List<int> selectedHeadings = [], selectedMenus = [];

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { username.dispose(); password.dispose(); email.dispose(); dept.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { busy = true; error = null; });
    try {
      final results = await Future.wait([
        widget.db.from('users').select('id,username,role,email,dept,project').order('id'),
        widget.db.from('main_heading_master').select('id,headingname').eq('status', '1').order('id'),
        widget.db.from('menu_master').select('id,menuname,main_heading_id').eq('status', '1').order('main_heading_id').order('id'),
        widget.db.from('user_main_heading_access').select('user_id,main_heading_id,main_heading_master(headingname)').order('main_heading_id'),
        widget.db.from('user_menu_access').select('user_id,menu_id,menu_master(menuname)').order('menu_id'),
      ]);
      final loadedUsers = List<Map<String, dynamic>>.from(results[0] as List);
      final loadedHeadings = List<Map<String, dynamic>>.from(results[1] as List);
      final loadedMenus = List<Map<String, dynamic>>.from(results[2] as List);
      final hMap = <int, List<String>>{}, mMap = <int, List<String>>{};
      for (final row in (results[3] as List)) {
        final id = (row['user_id'] as num).toInt();
        final name = row['main_heading_master']?['headingname']?.toString();
        if (name != null && name.isNotEmpty) (hMap[id] ??= []).add(name);
      }
      for (final row in (results[4] as List)) {
        final id = (row['user_id'] as num).toInt();
        final name = row['menu_master']?['menuname']?.toString();
        if (name != null && name.isNotEmpty) (mMap[id] ??= []).add(name);
      }
      if (!mounted) return;
      setState(() { users = loadedUsers; headings = loadedHeadings; menus = loadedMenus; headingNames = hMap; menuNames = mMap; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }

  List<Map<String, dynamic>> get filtered {
    final q = search.trim().toLowerCase();
    return users.where((u) {
      final text = '${u['username'] ?? ''} ${u['email'] ?? ''} ${u['dept'] ?? ''} ${u['project'] ?? ''}'.toLowerCase();
      final r = (u['role'] ?? 'user').toString().toLowerCase();
      return text.contains(q) && (roleFilter == 'all' || r == roleFilter);
    }).toList();
  }

  void openForm([Map<String, dynamic>? u]) async {
    editId = u == null ? null : (u['id'] as num).toInt();
    username.text = (u?['username'] ?? '').toString();
    password.clear(); email.text = (u?['email'] ?? '').toString(); dept.text = (u?['dept'] ?? '').toString();
    role = ((u?['role'] ?? 'user').toString().toLowerCase() == 'subadmin') ? 'subadmin' :
      ((u?['role'] ?? 'user').toString().toLowerCase() == 'admin') ? 'admin' : 'user';
    selectedHeadings = []; selectedMenus = [];
    if (editId != null) {
      try {
        final h = await widget.db.from('user_main_heading_access').select('main_heading_id').eq('user_id', editId!);
        final m = await widget.db.from('user_menu_access').select('menu_id').eq('user_id', editId!);
        selectedHeadings = h.map<int>((x) => (x['main_heading_id'] as num).toInt()).toList();
        selectedMenus = m.map<int>((x) => (x['menu_id'] as num).toInt()).toList();
      } catch (e) { setState(() => error = e.toString()); return; }
    }
    if (!mounted) return;
    showDialog<void>(context: context, barrierDismissible: !saving, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) {
      final availableMenus = menus.where((m) => selectedHeadings.contains((m['main_heading_id'] as num).toInt())).toList();
      return AlertDialog(
        title: Text(editId == null ? 'Add User Profile' : 'Edit User Profile'),
        content: SizedBox(width: 620, child: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: username, decoration: const InputDecoration(labelText: 'Username *'), validator: (v) => (v ?? '').trim().isEmpty ? 'Username is required' : null),
          const SizedBox(height: 8),
          TextFormField(controller: email, decoration: const InputDecoration(labelText: 'Email *'), keyboardType: TextInputType.emailAddress, validator: (v) => (v ?? '').trim().isEmpty ? 'Email is required' : null),
          const SizedBox(height: 8),
          TextFormField(controller: password, obscureText: true, decoration: InputDecoration(labelText: editId == null ? 'Password *' : 'New password (optional)'), validator: (v) => editId == null && (v ?? '').trim().isEmpty ? 'Password is required' : null),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: role, decoration: const InputDecoration(labelText: 'Role'), items: const [
            DropdownMenuItem(value: 'user', child: Text('User')), DropdownMenuItem(value: 'subadmin', child: Text('SubAdmin')), DropdownMenuItem(value: 'admin', child: Text('Admin')),
          ], onChanged: (v) => setDialog(() => role = v ?? 'user')),
          const SizedBox(height: 8),
          TextFormField(controller: dept, decoration: const InputDecoration(labelText: 'Department')),
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerLeft, child: Text('Main Heading Access', style: Theme.of(ctx).textTheme.titleMedium)),
          const SizedBox(height: 4),
          ...headings.map((h) {
            final id = (h['id'] as num).toInt();
            return CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: selectedHeadings.contains(id), title: Text((h['headingname'] ?? '').toString()), onChanged: (v) => setDialog(() {
              if (v == true) { if (!selectedHeadings.contains(id)) selectedHeadings.add(id); }
              else { selectedHeadings.remove(id); final menuIds = menus.where((m) => (m['main_heading_id'] as num).toInt() == id).map((m) => (m['id'] as num).toInt()).toSet(); selectedMenus.removeWhere(menuIds.contains); }
            }));
          }),
          const Divider(),
          Align(alignment: Alignment.centerLeft, child: Text('Menu Access', style: Theme.of(ctx).textTheme.titleMedium)),
          const SizedBox(height: 4),
          if (availableMenus.isEmpty) const Align(alignment: Alignment.centerLeft, child: Text('Select a main heading to see its menus.')),
          ...availableMenus.map((m) {
            final id = (m['id'] as num).toInt();
            Map<String, dynamic>? h;\n            for (final candidate in headings) { if ((candidate['id'] as num).toInt() == (m['main_heading_id'] as num).toInt()) { h = candidate; break; } }
            return CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: selectedMenus.contains(id), title: Text((m['menuname'] ?? '').toString()), subtitle: Text((h?['headingname'] ?? '').toString()), onChanged: (v) => setDialog(() { if (v == true) { if (!selectedMenus.contains(id)) selectedMenus.add(id); } else { selectedMenus.remove(id); } }));
          }),
        ]))),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(onPressed: saving ? null : () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            setState(() { saving = true; error = null; });
            try {
              if (editId == null) {
                final exists = await widget.db.from('users').select('id').eq('username', username.text.trim()).maybeSingle();
                if (exists != null) throw Exception('This username already exists.');
                final inserted = await widget.db.from('users').insert({
                  'username': username.text.trim(), 'password': password.text.trim(),
                  'role': role == 'admin' ? 'Admin' : role == 'subadmin' ? 'SubAdmin' : 'User',
                  'email': email.text.trim(), 'dept': dept.text.trim(),
                  'project': role == 'admin' ? 'All Main Headings' : headings.where((h) => selectedHeadings.contains((h['id'] as num).toInt())).map((h) => h['headingname']).join(', '),
                }).select('id').single();
                editId = (inserted['id'] as num).toInt();
              } else {
                final data = <String, dynamic>{
                  'username': username.text.trim(), 'role': role == 'admin' ? 'Admin' : role == 'subadmin' ? 'SubAdmin' : 'User',
                  'email': email.text.trim(), 'dept': dept.text.trim(),
                  'project': role == 'admin' ? 'All Main Headings' : headings.where((h) => selectedHeadings.contains((h['id'] as num).toInt())).map((h) => h['headingname']).join(', '),
                };
                if (password.text.trim().isNotEmpty) data['password'] = password.text.trim();
                await widget.db.from('users').update(data).eq('id', editId!);
              }
              final id = editId!;
              await widget.db.from('user_main_heading_access').delete().eq('user_id', id);
              if (selectedHeadings.isNotEmpty) await widget.db.from('user_main_heading_access').insert(selectedHeadings.map((v) => {'user_id': id, 'main_heading_id': v, 'created_by': widget.user['username']}).toList());
              await widget.db.from('user_menu_access').delete().eq('user_id', id);
              if (selectedMenus.isNotEmpty) await widget.db.from('user_menu_access').insert(selectedMenus.map((v) => {'user_id': id, 'menu_id': v, 'created_by': widget.user['username']}).toList());
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() { notice = editId == null ? 'User added successfully.' : 'User profile saved successfully.'; });
              await load();
            } catch (e) {
              if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
            } finally { if (mounted) setState(() => saving = false); if (ctx.mounted) setDialog(() {}); }
          }, icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: Text(saving ? 'Saving…' : 'Save Profile')),
        ],
      );
    }));
  }

  Future<void> deleteUser(Map<String, dynamic> u) async {
    final id = (u['id'] as num).toInt();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete user?'), content: Text('Delete ${u['username']} and its profile record?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
    if (ok != true) return;
    try {
      await widget.db.from('user_main_heading_access').delete().eq('user_id', id);
      await widget.db.from('user_menu_access').delete().eq('user_id', id);
      await widget.db.from('users').delete().eq('id', id);
      if (mounted) setState(() => notice = 'User deleted successfully.');
      await load();
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    final rows = filtered;
    final totalPages = (rows.length / pageSize).ceil().clamp(1, 999999);
    final safePage = page.clamp(1, totalPages);
    final start = rows.isEmpty ? 0 : (safePage - 1) * pageSize;
    final shown = rows.skip(start).take(pageSize).toList();
    final adminCount = users.where((u) => (u['role'] ?? '').toString().toLowerCase() == 'admin').length;
    final subCount = users.where((u) => (u['role'] ?? '').toString().toLowerCase() == 'subadmin').length;
    return ListView(padding: const EdgeInsets.all(18), children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('User Profiles', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), const Text('Manage user details, roles, main heading access and menu permissions.')])) , FilledButton.icon(onPressed: openForm, icon: const Icon(Icons.person_add_alt_1), label: const Text('Add User'))]),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _stat('Total Users', users.length, Icons.people_outline), _stat('Admins', adminCount, Icons.admin_panel_settings_outlined), _stat('SubAdmins', subCount, Icons.manage_accounts_outlined), _stat('Users', users.length - adminCount - subCount, Icons.person_outline),
      ]),
      const SizedBox(height: 14),
      TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search username, email, department or project'), onChanged: (v) => setState(() { search = v; page = 1; })),
      const SizedBox(height: 10),
      Wrap(spacing: 8, children: [
        for (final item in const [('all','All Roles'),('admin','Admin'),('subadmin','SubAdmin'),('user','User')])
          ChoiceChip(label: Text(item.$2), selected: roleFilter == item.$1, onSelected: (_) => setState(() { roleFilter = item.$1; page = 1; })),
      ]),
      if (notice != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(notice!, style: TextStyle(color: Theme.of(context).colorScheme.primary))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      if (busy) const LinearProgressIndicator(),
      const SizedBox(height: 10),
      if (shown.isEmpty && !busy) const Card(child: Padding(padding: EdgeInsets.all(22), child: Center(child: Text('No user profiles found.')))),
      ...shown.map((u) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [CircleAvatar(child: Text(((u['username'] ?? '?').toString().isEmpty ? '?' : (u['username'] ?? '?').toString()[0]).toUpperCase())), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((u['username'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), Text((u['email'] ?? 'No email').toString(), style: Theme.of(context).textTheme.bodySmall)])), Chip(label: Text((u['role'] ?? 'User').toString())), PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') openForm(u); if (v == 'delete') deleteUser(u); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit profile')), PopupMenuItem(value: 'delete', child: Text('Delete user'))])]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [if ((u['dept'] ?? '').toString().isNotEmpty) Chip(avatar: const Icon(Icons.apartment, size: 16), label: Text(u['dept'].toString())), if ((u['project'] ?? '').toString().isNotEmpty) Chip(avatar: const Icon(Icons.work_outline, size: 16), label: Text(u['project'].toString()))]),
        const SizedBox(height: 6),
        Text('Main Headings: ${(headingNames[(u['id'] as num).toInt()] ?? []).join(', ').isEmpty ? 'None assigned' : (headingNames[(u['id'] as num).toInt()] ?? []).join(', ')}', style: Theme.of(context).textTheme.bodySmall),
        Text('Menus: ${(menuNames[(u['id'] as num).toInt()] ?? []).join(', ').isEmpty ? 'None assigned' : (menuNames[(u['id'] as num).toInt()] ?? []).join(', ')}', style: Theme.of(context).textTheme.bodySmall),
      ])))),
      if (rows.isNotEmpty) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${start + 1}–${(start + shown.length)} of ${rows.length}'),
        Row(children: [DropdownButton<int>(value: pageSize, items: const [10,25,50].map((n) => DropdownMenuItem(value: n, child: Text('$n / page'))).toList(), onChanged: (v) => setState(() { pageSize = v ?? 10; page = 1; })), IconButton(onPressed: safePage > 1 ? () => setState(() => page = safePage - 1) : null, icon: const Icon(Icons.chevron_left)), Text('$safePage / $totalPages'), IconButton(onPressed: safePage < totalPages ? () => setState(() => page = safePage + 1) : null, icon: const Icon(Icons.chevron_right))]),
      ]),
    ]);
  }

  Widget _stat(String label, int value, IconData icon) => SizedBox(width: 160, child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(height: 8), Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), Text(label)]))));
}
