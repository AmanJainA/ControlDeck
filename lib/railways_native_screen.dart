import 'dart:convert';
import 'package:flutter/material.dart';
import 'shared/widgets/deck_components.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'supabase_config.dart';
import 'railways_data_manager.dart';

/// Native Flutter implementation of the Railways workspace.
class RailwaysNativeScreen extends StatefulWidget {
  const RailwaysNativeScreen({super.key});
  @override State<RailwaysNativeScreen> createState() => _RailwaysNativeScreenState();
}

class _RailwaysNativeScreenState extends State<RailwaysNativeScreen> {
  static const _storage = FlutterSecureStorage();
  static const _sessionKey = 'controldeck.railways.session.v1';
  late final SupabaseClient db;
  final search = TextEditingController();
  Map<String,dynamic>? user, heading, menu;
  List<Map<String,dynamic>> headings=[], menus=[], folders=[], files=[], trackingRows=[];
  Map<int,int> menuFolderCounts = {};
  Map<String, int> dashboardCounts = {'mydata': 0, 'nangia': 0, 'nr': 0};
  List<Map<String, dynamic>> latestMenus = [];
  int? selectedFolderId;
  int? dashboardHeadingId;
  String typeFilter='all', trackingTab='online', trackingSearch='';
  bool busy=true;
  String view='login';
  String? error;
  bool get admin => (user?['role']??'').toString().toLowerCase()=='admin';
  bool get canApprove => admin || (user?['role'] ?? '').toString().toLowerCase() == 'subadmin';

  @override void initState(){super.initState();db=SupabaseClient(SupabaseConfig.professionalUrl,SupabaseConfig.professionalKey);_restoreSession();}
  @override void dispose(){search.dispose();db.dispose();super.dispose();}

  String message(Object e){
    final s=e.toString().replaceFirst('Exception: ','');
    if(s.contains('Failed to fetch')||s.contains('SocketException'))return 'Cannot connect. Check your internet connection.';
    if(s.contains('permission denied')||s.contains('row-level security'))return 'Access denied by the Railway database policy.';
    return s;
  }


  Future<void> _restoreSession() async {
    // A cached Railway row is display data, not an authentication credential.
    // Always resolve the current ControlDeck Auth session through the SSO function.
    await _storage.delete(key: _sessionKey);
    await login();
  }

  Future<void> signOut() async {
    await _storage.delete(key: _sessionKey);
    try { await Supabase.instance.client.auth.signOut(); } catch (_) {}
    if (!mounted) return;
    setState(() { user = null; headings = []; menus = []; files = []; heading = null; menu = null; view = 'login'; error = null; });
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> login() async {
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    if (session == null || auth.currentUser == null) {
      if (mounted) setState(() { error = 'Sign in to ControlDeck first. Railways uses the same account and does not have a separate password.'; busy = false; });
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      // Call the Railways project's own function so it can use that project's
      // server-managed service role key without cross-project secrets.
      final response = await db.functions.invoke(
        'railways-sso',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        body: {'action': 'exchange', 'app': 'railways'},
      );
      final payload = Map<String, dynamic>.from(response.data as Map);
      if (response.status < 200 || response.status >= 300 || payload['ok'] != true) {
        throw Exception((payload['error'] ?? 'Could not verify your Railways access.').toString());
      }
      final row = Map<String, dynamic>.from(payload['user'] as Map);
      if (!mounted) return;
      setState(() { user = row; view = 'home'; });
      // Keep the existing Railways schema and access tables unchanged.
      await _storage.write(key: _sessionKey, value: jsonEncode(row));
      await loadHeadings();
      await loadDashboardSummary();
    } catch (e) {
      if (mounted) setState(() { user = null; view = 'login'; error = message(e); });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadHeadings() async {
    if(user==null)return;
    setState(() { busy = true; error = null; });
    try{
      final rows=await db.from('main_heading_master').select('id,headingname,status').eq('status','1').order('id');
      var result=List<Map<String,dynamic>>.from(rows);
      if(!admin){
        final access=await db.from('user_main_heading_access').select('main_heading_id').eq('user_id',user!['id']);
        final ids=access.map((r)=>(r['main_heading_id'] as num).toInt()).toSet();
        result=result.where((h)=>ids.contains((h['id'] as num).toInt())).toList();
      }
      if(mounted)setState(() { headings = result; view = 'home'; });
    }catch(e){if(mounted)setState(()=>error=message(e));}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> loadDashboardSummary() async {
    try {
      final raw = await db.from('datacollection')
          .select('id,menuname,menu_id,main_heading_id,type,links,folder');
      final rows = List<Map<String, dynamic>>.from(raw);
      var myDataCount = 0;
      var nangiaCount = 0;
      final grouped = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final name = (row['menuname'] ?? '').toString().trim();
        final normalized = name.toLowerCase().replaceAll(RegExp(r'[ _-]'), '');
        if (normalized == 'mydata') myDataCount++;
        if (normalized == 'nangia') nangiaCount++;
        if (name.isEmpty || normalized == 'mydata' || normalized == 'nangia') continue;
        final menuId = (row['menu_id'] as num?)?.toInt();
        final headingId = (row['main_heading_id'] as num?)?.toInt();
        final key = menuId != null ? 'menu:$menuId' : 'heading:${headingId ?? 0}:${normalized}';
        grouped.putIfAbsent(key, () => {
          'name': name,
          'menu_id': menuId,
          'main_heading_id': headingId,
          'count': 0,
        });
        grouped[key]!['count'] = (grouped[key]!['count'] as int) + 1;
      }
      final recent = grouped.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      if (!mounted) return;
      setState(() {
        dashboardCounts = {
          'mydata': myDataCount,
          'nangia': nangiaCount,
          'nr': rows.length - myDataCount - nangiaCount,
        };
        latestMenus = recent.take(8).toList();
      });
    } catch (_) {
      // Keep the workspace usable if dashboard-wide counts are restricted by RLS.
    }
  }

  Future<void> openDashboardMenu(Map<String, dynamic> item) async {
    final menuId = (item['menu_id'] as num?)?.toInt();
    final headingId = (item['main_heading_id'] as num?)?.toInt();
    if (menuId == null || headingId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This menu is not linked to an active workspace.')),
      );
      return;
    }
    try {
      final headingRow = await db.from('main_heading_master')
          .select('id,headingname,status').eq('id', headingId).maybeSingle();
      final menuRow = await db.from('menu_master')
          .select('id,menuname,status,main_heading_id').eq('id', menuId).maybeSingle();
      if (headingRow == null || menuRow == null) throw Exception('The selected menu is no longer available.');
      await openHeading(Map<String, dynamic>.from(headingRow));
      await openMenu(Map<String, dynamic>.from(menuRow));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message(e))));
    }
  }

  Future<void> openHeading(Map<String,dynamic> h) async {
    setState(() { heading = h; menu = null; menus = []; files = []; view = 'menus'; busy = true; error = null; });
    try{
      final rows=await db.from('menu_master').select('id,menuname,status,main_heading_id').eq('main_heading_id',h['id']).eq('status','1').order('id');
      var result=List<Map<String,dynamic>>.from(rows);
      if(!admin){
        final access=await db.from('user_menu_access').select('menu_id').eq('user_id',user!['id']);
        final ids=access.map((r)=>(r['menu_id'] as num).toInt()).toSet();
        result=result.where((m)=>ids.contains((m['id'] as num).toInt())).toList();
      }
      if (!mounted) return;
      setState(() { menus = result; });
      // NR Data owns its dashboard. Keep its document summary and menu tabs
      // inside that workspace rather than adding another top-level destination.
      if ((h['headingname'] ?? '').toString().trim().toLowerCase() == 'nr data') {
        await openNRDashboardForHeading(h, result);
      }
    }catch(e){if(mounted)setState(()=>error=message(e));}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> openNRDashboardForHeading(Map<String,dynamic> h, List<Map<String,dynamic>> headingMenus) async {
    final id = (h['id'] as num).toInt();
    setState(() {
      heading = h;
      dashboardHeadingId = id;
      menu = null;
      menus = headingMenus;
      view = 'nr';
      files = [];
      search.clear();
      busy = true;
      error = null;
    });
    try {
      final raw = await db.from('datacollection')
          .select('id,name,links,type,status,remark,uploaded_by,uploaded_at,main_heading_id,menu_id,folder_id,menuname,folder,source_type')
          .eq('status', 1).eq('main_heading_id', id).order('id', ascending: false);
      final folderRows = await db.from('folder_master')
          .select('id,menu_id').eq('main_heading_id', id).eq('status', '1');
      final folderCounts = <int,int>{};
      for (final folder in folderRows) {
        final menuId = (folder['menu_id'] as num?)?.toInt();
        if (menuId != null) folderCounts[menuId] = (folderCounts[menuId] ?? 0) + 1;
      }
      if (mounted) setState(() {
        files = List<Map<String,dynamic>>.from(raw);
        menuFolderCounts = folderCounts;
      });
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openMenu(Map<String,dynamic> m) async {
    setState(() { menu = m; view = 'files'; files = []; folders = []; selectedFolderId = null; typeFilter = 'all'; search.clear(); busy = true; error = null; });
    try{
      final folderRows = await db.from('folder_master').select('id,foldername,menu_id,main_heading_id,status').eq('menu_id', m['id']).eq('status', '1').order('id');
      final rows=await db.from('datacollection').select('id,name,type,links,menuname,folder,folder_id,menu_id,status,remark,uploaded_by,uploaded_at')
        .eq('menu_id',m['id']).eq('status',1).order('id',ascending:false);
      if(mounted)setState(() { folders = List<Map<String,dynamic>>.from(folderRows); files = List<Map<String,dynamic>>.from(rows); });
    }catch(e){if(mounted)setState(()=>error=message(e));}
    finally{if(mounted)setState(()=>busy=false);}
  }


  Future<void> uploadLink() async {
    final title = TextEditingController();
    final link = TextEditingController();
    int? headingId = headings.isEmpty ? null : (headings.first['id'] as num).toInt();
    int? menuId;
    List<Map<String,dynamic>> availableMenus = [], availableFolders = [];
    int? folderId;
    PlatformFile? picked;
    String mode = 'file';
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: const Text('Submit a document'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SegmentedButton<String>(segments: const [
          ButtonSegment(value: 'file', label: Text('Upload file'), icon: Icon(Icons.upload_file)),
          ButtonSegment(value: 'link', label: Text('Cloud link'), icon: Icon(Icons.link)),
        ], selected: {mode}, onSelectionChanged: (v) => setDialog(() => mode = v.first)),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(value: headingId, decoration: const InputDecoration(labelText: 'Main heading'),
          items: headings.map((h) => DropdownMenuItem<int>(value: (h['id'] as num).toInt(), child: Text((h['headingname'] ?? '').toString()))).toList(),
          onChanged: (v) async {
            headingId = v; menuId = null; folderId = null; availableMenus = []; availableFolders = [];
            if (v != null) {
              final raw = await db.from('menu_master').select('id,menuname').eq('main_heading_id', v).eq('status', '1').order('id');
              availableMenus = List<Map<String,dynamic>>.from(raw);
              if (!admin) {
                final access = await db.from('user_menu_access').select('menu_id').eq('user_id', user!['id']);
                final allowed = access.map((x) => (x['menu_id'] as num).toInt()).toSet();
                availableMenus = availableMenus.where((m) => allowed.contains((m['id'] as num).toInt())).toList();
              }
            }
            setDialog(() {});
          }),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(value: menuId, decoration: const InputDecoration(labelText: 'Menu'),
          items: availableMenus.map((m) => DropdownMenuItem<int>(value: (m['id'] as num).toInt(), child: Text((m['menuname'] ?? '').toString()))).toList(),
          onChanged: (v) async {
            menuId = v; folderId = null; availableFolders = [];
            if (v != null && headingId != null) {
              final raw = await db.from('folder_master').select('id,foldername').eq('main_heading_id', headingId!).eq('menu_id', v).eq('status', '1').order('id');
              availableFolders = List<Map<String,dynamic>>.from(raw);
            }
            setDialog(() {});
          }),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(value: folderId, decoration: const InputDecoration(labelText: 'Folder (optional)'),
          items: availableFolders.map((f) => DropdownMenuItem<int>(value: (f['id'] as num).toInt(), child: Text((f['foldername'] ?? '').toString()))).toList(),
          onChanged: (v) => setDialog(() => folderId = v)),
        const SizedBox(height: 10),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Document title')),
        if (mode == 'file')
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['jpg','jpeg','png','gif','pdf','doc','docx','xls','xlsx','ppt','pptx']);
              if (result != null && result.files.isNotEmpty) { picked = result.files.first; setDialog(() {}); }
            },
            icon: const Icon(Icons.attach_file), label: Text(picked?.name ?? 'Choose file'),
          ))
        else
          TextField(controller: link, decoration: const InputDecoration(labelText: 'OneDrive / cloud URL')),
        const SizedBox(height: 6),
        Text('New submissions stay pending until an administrator approves them.', style: Theme.of(ctx).textTheme.bodySmall),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit'))],
    )));
    if (accepted == true) {
      try {
        if (headingId == null || menuId == null || title.text.trim().isEmpty) throw Exception('Select a heading and menu and enter a document title.');
        String storedLink = link.text.trim();
        String type = 'ONEDRIVE';
        String sourceType = 'onedrive_path';
        if (mode == 'file') {
          final bytes = picked?.bytes;
          if (picked == null || bytes == null) throw Exception('Choose a file first.');
          final ext = (picked!.extension ?? '').toLowerCase();
          if (!['jpg','jpeg','png','gif','pdf','doc','docx','xls','xlsx','ppt','pptx'].contains(ext)) throw Exception('This file type is not supported.');
          final path = DateTime.now().millisecondsSinceEpoch.toString() + '_' + picked!.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
          await db.storage.from('documents').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));
          storedLink = path; type = ext; sourceType = 'file_upload';
        } else {
          final uri = Uri.tryParse(storedLink);
          if (uri == null || !uri.hasScheme || !(uri.scheme == 'https' || uri.scheme == 'http')) throw Exception('Enter a valid cloud URL.');
        }
        final selectedMenu = availableMenus.firstWhere((m) => (m['id'] as num).toInt() == menuId);
        final selectedFolder = availableFolders.where((f) => (f['id'] as num).toInt() == folderId).firstOrNull;
        final inserted = await db.from('datacollection').insert({
          'name': title.text.trim(), 'links': storedLink, 'type': type, 'menuname': selectedMenu['menuname'],
          'folder': selectedFolder?['foldername'], 'folder_id': folderId,
          'main_heading_id': headingId, 'menu_id': menuId, 'status': 0, 'uploaded_by': user?['username'],
          'uploaded_at': DateTime.now().toIso8601String(), 'source_type': sourceType,
        }).select('id').single();
        try {
          await db.from('file_uploads').insert({'datacollection_id': inserted['id'], 'uploaded_by': user?['username'], 'upload_time': DateTime.now().toIso8601String()});
        } catch (_) {
          // The document submission remains valid even if the optional audit log is restricted by database policy.
        }
        if (mounted) {
          setState(() => error = null);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document submitted for approval.')));
        }
      } catch (e) {
        if (mounted) setState(() => error = message(e));
      }
    }
    title.dispose(); link.dispose();
  }

  String _formatDateTime(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '—';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final local = parsed.toLocal();
    final date = '${local.day}-${local.month}-${(local.year % 100).toString().padLeft(2, '0')}';
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final time = '${hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
    return '$date · $time';
  }

  Future<void> openMyData() async {
    setState(() { menu = {'menuname':'My Data'}; heading = null; view = 'files'; files = []; folders = []; selectedFolderId = null; search.clear(); busy = true; error = null; });
    try{
      final rows=await db.from('datacollection').select('id,name,type,links,menuname,folder,folder_id,menu_id,status,remark,uploaded_by,uploaded_at')
        .eq('menuname','mydata').order('id',ascending:false);
      if(mounted)setState(() { files = List<Map<String,dynamic>>.from(rows); });
    }catch(e){if(mounted)setState(()=>error=message(e));}
    finally{if(mounted)setState(()=>busy=false);}
  }




  Future<void> openNangia() async {
    setState(() {
      menu = {'menuname': 'Nangia'};
      heading = null;
      view = 'nangia';
      files = [];
      folders = [];
      selectedFolderId = null;
      typeFilter = 'all';
      search.clear();
      busy = true;
      error = null;
    });
    try {
      // Match the web portal's Nangia register: documents are grouped by
      // the exact "Nangia" menu label and newest records appear first.
      final rows = await db.from('datacollection')
          .select('id,name,type,links,menuname,folder,folder_id,menu_id,status,remark,uploaded_by,uploaded_at,source_type')
          .eq('menuname', 'Nangia')
          .order('id', ascending: false);
      if (mounted) setState(() { files = List<Map<String, dynamic>>.from(rows); });
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changePassword() async {
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirm = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Change Railway password'),
      content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: oldPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
        const SizedBox(height: 10),
        TextField(controller: newPassword, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
        const SizedBox(height: 10),
        TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update password'))],
    ));
    if (accepted == true) {
      try {
        if (newPassword.text.length < 8) throw Exception('Use at least 8 characters for the new password.');
        if (newPassword.text != confirm.text) throw Exception('The new passwords do not match.');
        final result = await db.from('users').update({'password': newPassword.text}).eq('id', user!['id']).eq('password', oldPassword.text).select('id').maybeSingle();
        if (result == null) throw Exception('The current password is incorrect.');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Railway password updated.')));
      } catch (e) { if (mounted) setState(() => error = message(e)); }
    }
    oldPassword.dispose(); newPassword.dispose(); confirm.dispose();
  }

  Future<void> openNRDashboard() async {
    setState(() { view = 'nr'; dashboardHeadingId = null; heading = null; menus = []; files = []; search.clear(); busy = true; error = null; });
    try {
      var query = db.from('datacollection')
          .select('id,name,links,type,status,remark,uploaded_by,uploaded_at,main_heading_id,menu_id,folder_id,menuname,folder,source_type')
          .eq('status', 1);
      if (!admin) {
        final allowedHeadingIds = headings.map((h) => (h['id'] as num).toInt()).toList();
        if (allowedHeadingIds.isEmpty) {
          if (mounted) setState(() { files = []; busy = false; });
          return;
        }
        query = query.inFilter('main_heading_id', allowedHeadingIds);
      }
      final raw = await query.order('id', ascending: false);
      if (mounted) setState(() { files = List<Map<String,dynamic>>.from(raw); });
    } catch (e) { if (mounted) setState(() => error = message(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> openPendingApprovals() async {
    setState(() { view = 'pending'; files = []; busy = true; error = null; });
    try {
      var query = db.from('datacollection').select('id,name,links,type,status,remark,uploaded_by,uploaded_at,main_heading_id,menu_id,folder_id,menuname,folder,source_type').eq('status', 0);
      if (!admin) {
        final ids = headings.map((h) => (h['id'] as num).toInt()).toList();
        if (ids.isEmpty) { if (mounted) setState(() { files = []; busy = false; }); return; }
        query = query.inFilter('main_heading_id', ids);
      }
      final raw = await query.order('id', ascending: false);
      if (mounted) setState(() { files = List<Map<String,dynamic>>.from(raw); });
    } catch (e) { if (mounted) setState(() => error = message(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> loadTracking(String tab) async {
    if (!admin) return;
    final table = tab == 'online' ? 'user_presence' : tab == 'login' ? 'login_history' : 'page_activity';
    setState(() { view = 'tracking'; trackingTab = tab; trackingRows = []; trackingSearch = ''; busy = true; error = null; });
    try {
      final raw = await db.from(table).select('*').limit(500);
      var rows = List<Map<String,dynamic>>.from(raw);
      if (tab == 'online' && rows.isNotEmpty) {
        final userIds = rows.map((r) => r['user_id']).where((id) => id != null).toSet().toList();
        final userRows = userIds.isEmpty ? <dynamic>[] : await db.from('users').select('id,username,email,role').inFilter('id', userIds);
        final usersById = {for (final u in userRows) u['id'].toString(): u};
        rows = rows.map((r) {
          final u = usersById[(r['user_id'] ?? '').toString()] ?? <String,dynamic>{};
          final lastSeen = DateTime.tryParse((r['last_seen'] ?? r['last_activity'] ?? '').toString());
          final active = lastSeen != null && DateTime.now().difference(lastSeen.toLocal()).inMinutes <= 5;
          return <String,dynamic>{
            'username': u['username'] ?? r['username'] ?? '—',
            'email': u['email'] ?? r['email'] ?? '—',
            'role': u['role'] ?? r['role'] ?? '—',
            'last_activity_status': active ? 'Online' : 'Inactive',
          };
        }).toList();
      }
      if (mounted) setState(() { trackingRows = rows; });
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> updateApproval(Map<String,dynamic> file, int status) async {
    final remark = TextEditingController(text: (file['remark'] ?? '').toString());
    if (status == 2) {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Reject document'),
        content: TextField(controller: remark, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Reason / remark')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject'))],
      ));
      if (ok != true) { remark.dispose(); return; }
    }
    try {
      await db.from('datacollection').update({'status': status, 'remark': remark.text.trim()}).eq('id', file['id']);
      await openPendingApprovals();
    } catch (e) { if (mounted) setState(() => error = message(e)); }
    remark.dispose();
  }

  Future<void> openNativeManager(String table, String title) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RailwaysDataManager(db: db, user: user!, table: table, title: title)));
    if (mounted) {
      if (view == 'home') await loadHeadings();
      if (view == 'files') await openMyData();
    }
  }

  void back(){
    if(view=='files'&&heading!=null){openHeading(heading!);return;}
    if(view=='files'||view=='menus'||view=='nangia'||view=='pending'||view=='nr'||view=='tracking'||view=='users'){setState(() { view = 'home'; heading = null; menu = null; });return;}
    Navigator.of(context).maybePop();
  }

  bool _matchesTypeFilter(Map<String, dynamic> file) {
    if (typeFilter == 'all') return true;
    final values = [
      file['type'],
      file['name'],
      file['links'],
    ].where((value) => value != null).map((value) => value.toString().toLowerCase()).toList();
    final typeText = values.join(' ');
    switch (typeFilter) {
      case 'img':
        return ['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'bmp', 'tif', 'tiff']
            .any((ext) => RegExp(r'(^|[. /])' + ext + r'($|[? ;/])').hasMatch(typeText))
            || typeText.contains('image/');
      case 'pdf':
        return typeText.contains('pdf') || typeText.contains('application/pdf');
      case 'doc':
        return ['doc', 'docx', 'odt', 'rtf'].any((ext) =>
            RegExp(r'(^|[. /])' + ext + r'($|[? ;/])').hasMatch(typeText))
            || typeText.contains('wordprocessingml') || typeText.contains('msword');
      case 'xls':
        return ['xls', 'xlsx', 'csv', 'ods'].any((ext) =>
            RegExp(r'(^|[. /])' + ext + r'($|[? ;/])').hasMatch(typeText))
            || typeText.contains('spreadsheet') || typeText.contains('excel') || typeText.contains('text/csv');
      default:
        return true;
    }
  }

  Future<void> openDocument(Map<String,dynamic> file) async {
    final link = (file['links'] ?? '').toString().trim();
    if (link.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No document link is saved.')));
      return;
    }
    Uri? uri = Uri.tryParse(link);
    if (uri == null || !uri.hasScheme) {
      try {
        uri = Uri.parse(await db.storage.from('documents').createSignedUrl(link, 300));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message(e))));
        return;
      }
    }
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open this document.')));
    }
  }

  Future<void> showFile(Map<String,dynamic> f) async {
    final link=(f['links']??'').toString().trim();
    await showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,builder:(ctx)=>SafeArea(child:Padding(
      padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text((f['name']??'Document').toString(),style:Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
        const SizedBox(height:14),
        detail('Type',(f['type']??'Unknown').toString()),
        const SizedBox(height:16),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:link.isEmpty?null:()=>openDocument(f),icon:const Icon(Icons.open_in_new_rounded),label:const Text('Open'))),
      ]))));
  }

  Widget detail(String k,String v)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Row(children:[
    SizedBox(width:105,child:Text(k,style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant))),Expanded(child:SelectableText(v))
  ]));

  @override Widget build(BuildContext context){
    final title=view=='files'?(menu?['menuname']??'Files').toString():view=='menus'?(heading?['headingname']??'Workspace').toString():view=='tracking'?'Manage Tracking':view=='users'?'User Access':view=='nr'?(dashboardHeadingId==null?'Northern Railway Dashboard':(heading?['headingname']??'NR Data Dashboard').toString()):'Railways';
    return Scaffold(appBar:AppBar(
      leading:IconButton(onPressed:user==null?()=>Navigator.of(context).maybePop():back,icon:const Icon(Icons.arrow_back_rounded)),
      title:Text(title),
      actions:[
        if(user!=null)IconButton(tooltip:'Refresh',onPressed:view=='files'?(heading==null?openMyData:()=>openMenu(menu!)):view=='menus'?()=>openHeading(heading!):view=='pending'?openPendingApprovals:view=='tracking'?()=>loadTracking(trackingTab):view=='users'?()=>setState((){}):view=='nr'?openNRDashboard:loadHeadings,icon:const Icon(Icons.refresh_rounded)),
        if(user!=null)IconButton(tooltip:'Sign out',onPressed:signOut,icon:const Icon(Icons.logout_rounded)),
      ],
    ),body:user==null?openingDashboardView():workspaceView(),
      bottomNavigationBar:user==null?null:NavigationBar(
        selectedIndex: _selectedMainTab,
        onDestinationSelected: _selectMainTab,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations:[
          const NavigationDestination(icon:Icon(Icons.home_rounded),label:'Home'),
          const NavigationDestination(icon:Icon(Icons.cloud_upload_outlined),label:'Upload Files'),
          if(admin) const NavigationDestination(icon:Icon(Icons.manage_accounts_outlined),label:'User Access'),
          if(admin) const NavigationDestination(icon:Icon(Icons.monitor_heart_outlined),label:'Manage Tracking'),
        ],
      ));
  }

  int get _selectedMainTab {
    if (view == 'tracking' && admin) return 3;
    if (view == 'users' && admin) return 2;
    return 0;
  }

  void _selectMainTab(int index){
    if(index==0){setState(()=>view='home');loadHeadings();}
    else if(index==1)uploadLink();
    else if(index==2&&admin)setState(()=>view='users');
    else if(index==3&&admin)loadTracking('online');
  }

  Widget openingDashboardView()=>Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1100),child:ListView(padding:const EdgeInsets.all(20),children:[
    hero('Railways Dashboard','Your workspaces, documents and tools',Icons.train_rounded),
    const SizedBox(height:16),
    const LinearProgressIndicator(),
    const SizedBox(height:16),
    LayoutBuilder(builder:(ctx,c){final cols=c.maxWidth>700?3:c.maxWidth>460?2:1;return GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:cols,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:cols==1?4:2.3,children:[
      metric('Workspaces','—',Icons.account_tree_rounded),metric('Documents','—',Icons.description_outlined),metric('Access','—',Icons.verified_user_outlined)
    ]);}),
    if(error!=null) Padding(padding:const EdgeInsets.only(top:12),child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      const SizedBox(height:8),
      Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:busy?null:login,icon:const Icon(Icons.refresh_rounded),label:const Text('Retry connection'))),
    ])))),
    const SizedBox(height:8),
    const Card(child:ListTile(leading:Icon(Icons.folder_copy_outlined),title:Text('My Data'),subtitle:Text('Your submitted railway documents'))),
    const Card(child:ListTile(leading:Icon(Icons.dashboard_customize_outlined),title:Text('NR Data Dashboard'),subtitle:Text('Workspace dashboard and menu tabs load here after access is confirmed'))),
  ])));

  Widget loginView()=>Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(24),children:[
    Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(colors:[Color(0xFF102D4D),Color(0xFF176B87)])),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(Icons.train_rounded,size:42,color:Colors.white),SizedBox(height:14),
      Text('Railway workspace',style:TextStyle(fontSize:25,color:Colors.white,fontWeight:FontWeight.w800)),
      SizedBox(height:6),Text('Your ControlDeck account is used for Railways too.',style:TextStyle(color:Colors.white70)),
    ])),
    const SizedBox(height:22),
    const ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.verified_user_outlined),title:Text('Single sign-on'),subtitle:Text('No separate Railway username or password is required. Your access is matched to your existing Railway account by the verified server-side identity mapping.')),
    if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    const SizedBox(height:18),
    FilledButton.icon(onPressed:busy?null:login,icon:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.login_rounded),label:Text(busy?'Checking access…':'Continue with ControlDeck')),
  ])));

  Widget workspaceView(){
    if(view=='users'&&admin) return RailwaysDataManager(key:const ValueKey('railways-user-access-tab'),db:db,user:user!,table:'users',title:'User Access',embedded:true);
    final filtered=files.where((f){
      final typeMatch = _matchesTypeFilter(f);
      return (selectedFolderId==null||(f['folder_id'] as num?)?.toInt()==selectedFolderId)&&typeMatch&&'${f['name']??''} ${f['type']??''} ${f['folder']??''} ${f['uploaded_by']??''}'.toLowerCase().contains(search.text.toLowerCase());
    }).toList();
    return Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1100),child:ListView(padding:const EdgeInsets.all(20),children:[
      if(error!=null)Card(color:Theme.of(context).colorScheme.errorContainer,child:Padding(padding:const EdgeInsets.all(14),child:Text(error!))),
      if(busy)const LinearProgressIndicator(),
      if(view=='home')...[
        hero('Welcome, ${user?['username']??'Railway user'}','${user?['dept']??'Railway workspace'} · ${user?['role']??'User'}',Icons.train_rounded),
        const SizedBox(height:16),
        LayoutBuilder(builder:(ctx,c){final cols=c.maxWidth>900?3:2;return GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:cols,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:cols==2?1.55:2.3,children:[
          metric('Workspaces',headings.length.toString(),Icons.account_tree_rounded),metric('My Data',(dashboardCounts['mydata']??0).toString(),Icons.folder_copy_outlined),metric('Nangia',(dashboardCounts['nangia']??0).toString(),Icons.business_center_outlined),metric('NR Data',(dashboardCounts['nr']??0).toString(),Icons.description_outlined),metric('Role',(user?['role']??'User').toString(),Icons.verified_user_outlined),metric('Project',(user?['project']??'Railways').toString(),Icons.business_center_outlined)
        ]);}),
        const SizedBox(height:18),
        Row(children:[Expanded(child:Text('Workspaces',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800))),TextButton.icon(onPressed:openMyData,icon:const Icon(Icons.folder_copy_outlined),label:const Text('My Data'))]),
        if(headings.isEmpty)const EmptyRailway(title:'No workspaces assigned',detail:'Ask your administrator to grant access.'),
        for(final h in headings)Card(margin:const EdgeInsets.only(bottom:5),child:ListTile(leading:const CircleAvatar(child:Icon(Icons.account_tree_rounded)),title:Text((h['headingname']??'Workspace').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:const Text('Open menus and documents'),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>openHeading(h))),
        const SizedBox(height:20),
        Text('Railway tools', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height:8),
        Card(margin:const EdgeInsets.only(bottom:5),child: ListTile(leading: const Icon(Icons.folder_copy_outlined), title: const Text('My Data'), subtitle: const Text('View your submissions'), trailing: const Icon(Icons.chevron_right_rounded), onTap: openMyData)),
        Card(margin:const EdgeInsets.only(bottom:5),child: ListTile(leading: const Icon(Icons.business_center_outlined), title: const Text('Nangia'), subtitle: const Text('Browse Nangia documents and project files'), trailing: const Icon(Icons.chevron_right_rounded), onTap: openNangia)),
        if (canApprove) Card(margin:const EdgeInsets.only(bottom:5),child: ListTile(leading: const Icon(Icons.fact_check_outlined), title: const Text('Pending Approvals'), subtitle: const Text('Approve or reject submitted files'), trailing: const Icon(Icons.chevron_right_rounded), onTap: openPendingApprovals)),
        if (admin) ...[
          Card(margin:const EdgeInsets.only(bottom:5),child: ListTile(leading: const Icon(Icons.file_present_outlined), title: const Text('Manage Uploads'), subtitle: const Text('Edit or delete document metadata'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => openNativeManager('datacollection', 'Manage Uploads'))),
          Card(margin:const EdgeInsets.only(bottom:5),child: ListTile(leading: const Icon(Icons.account_tree_outlined), title: const Text('Main Headings'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => openNativeManager('main_heading_master', 'Main Headings'))),
          Card(margin:const EdgeInsets.only(bottom:5),child: ListTile(leading: const Icon(Icons.menu_open_rounded), title: const Text('Manage Menus'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => openNativeManager('menu_master', 'Manage Menus'))),
          Card(margin:const EdgeInsets.only(bottom:5),child: ListTile(leading: const Icon(Icons.folder_outlined), title: const Text('Manage Folders'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => openNativeManager('folder_master', 'Manage Folders'))),
          Card(margin:const EdgeInsets.only(bottom:5),child: ListTile(leading: const Icon(Icons.task_alt_rounded), title: const Text('Work Tracker'), subtitle: const Text('Manage tasks, reports and due dates'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => openNativeManager('work_items', 'Work Tracker'))),
        ],
      ]else if(view=='nr')...[
        hero('NR Data Dashboard','Your dashboard and menus in one workspace.',Icons.dashboard_customize_outlined),
        const SizedBox(height:12),
        LayoutBuilder(builder:(ctx,c){
          final total = files.length;
          final cols=c.maxWidth>700?3:c.maxWidth>460?2:1;
          return GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:cols,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:cols==1?4:2.3,children:[
            metric('Approved documents',total.toString(),Icons.description_outlined),
            metric('Menus',menus.length.toString(),Icons.menu_open_rounded),
            metric('Folders',files.where((f)=>(f['folder_id'] as num?)!=null).map((f)=>f['folder_id']).toSet().length.toString(),Icons.folder_copy_outlined),
          ]);
        }),
        const SizedBox(height:18),
        Text('Menus',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
        const SizedBox(height:8),
        if(menus.isEmpty)const EmptyRailway(title:'No menus available',detail:'No active menus or access grants were found for NR Data.'),
        for(final m in menus)
          Builder(builder:(ctx){
            final id=(m['id'] as num).toInt();
            final count=files.where((f)=>(f['menu_id'] as num?)?.toInt()==id).length;
            final folderCount = menuFolderCounts[id] ?? 0;
            final hasFolders = folderCount > 0;
            return Card(margin:const EdgeInsets.only(bottom:5),clipBehavior:Clip.antiAlias,child:ListTile(
              leading:const CircleAvatar(child:Icon(Icons.folder_open_rounded)),
              title:Text((m['menuname']??'Menu').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),
              subtitle:Text('$count approved documents' + (hasFolders ? ' · $folderCount folders' : ' · No folders')),
              trailing:const Icon(Icons.chevron_right_rounded),
              onTap:()=>openMenu(m),
            ));
          }),
      ]else if(view=='nangia')...[
        hero('Nangia', 'Browse the Nangia document register, search files and open project documents.', Icons.business_center_outlined),
        const SizedBox(height:12),
        TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),labelText:'Search Nangia documents')),
        const SizedBox(height:10),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[for(final t in const ['all','img','pdf','doc','xls'])Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(t=='all'?'All types':t.toUpperCase()),selected:typeFilter==t,onSelected:(_)=>setState(()=>typeFilter=t)))])),
        const SizedBox(height:10),
        if(!busy && filtered.isEmpty)const EmptyRailway(title:'No Nangia documents found',detail:'No records match the Nangia menu or your search.'),
        for(final f in filtered)
          Card(margin:const EdgeInsets.only(bottom:5),clipBehavior:Clip.antiAlias,child:ListTile(
            leading:fileIcon((f['type']??'').toString()),
            title:Text((f['name']??'Untitled document').toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text([
              (f['type']??'FILE').toString().toUpperCase(),
              if((f['uploaded_by']??'').toString().isNotEmpty) 'Uploaded by ${f['uploaded_by']}',
              if(_formatDateTime(f['uploaded_at']).isNotEmpty) (f['uploaded_at']??'').toString(),
            ].join(' · '),maxLines:2,overflow:TextOverflow.ellipsis),
            trailing:IconButton(tooltip:'Open document',onPressed:()=>openDocument(f),icon:const Icon(Icons.open_in_new_rounded)),
            onTap:()=>showFile(f),
          )),
      ]else if(view=='pending')...[
        hero('Pending Approvals', 'Approve or reject documents submitted by Railway users.', Icons.fact_check_outlined),
        if(files.isEmpty)const EmptyRailway(title:'No pending documents',detail:'There are no submissions waiting for approval.'),
        if(files.isNotEmpty)Card(clipBehavior:Clip.antiAlias,child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:const [DataColumn(label:Text('Document')),DataColumn(label:Text('Menu')),DataColumn(label:Text('Uploaded by')),DataColumn(label:Text('Uploaded at')),DataColumn(label:Text('Decision'))],rows:files.map((f)=>DataRow(onSelectChanged:(_)=>showFile(f),cells:[DataCell(SizedBox(width:220,child:Text((f['name']??'Document').toString(),maxLines:2,overflow:TextOverflow.ellipsis))),DataCell(Text((f['menuname']??'—').toString())),DataCell(Text((f['uploaded_by']??'—').toString())),DataCell(Text((f['uploaded_at']??'—').toString())),DataCell(PopupMenuButton<String>(tooltip:'Review submission',onSelected:(v){if(v=='approve')updateApproval(f,1);if(v=='reject')updateApproval(f,2);},itemBuilder:(_)=>const [PopupMenuItem(value:'approve',child:Text('Approve')),PopupMenuItem(value:'reject',child:Text('Reject'))],child:const Icon(Icons.more_horiz_rounded)))])).toList()))),
      ]else if(view=='tracking')...[
        trackingContent(),
      ]else if(view=='menus')...[
        hero((heading?['headingname']??'Workspace').toString(),'Choose a menu to browse its files.',Icons.folder_open_rounded),const SizedBox(height:14),
        if(menus.isEmpty)const EmptyRailway(title:'No menus available',detail:'No active menus or access grants were found.'),
        for(final m in menus)Card(child:ListTile(leading:const Icon(Icons.folder_copy_outlined),title:Text((m['menuname']??'Menu').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>openMenu(m))),
      ]else...[
        hero((menu?['menuname']??'Files').toString(),'${filtered.length} records · searchable document register',Icons.description_outlined),const SizedBox(height:14),
        if (folders.isNotEmpty) SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:const Text('All'),selected:selectedFolderId==null,onSelected:(_)=>setState(()=>selectedFolderId=null))),for(final folder in folders)Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text((folder['foldername']??'Folder').toString()),selected:selectedFolderId==(folder['id'] as num).toInt(),onSelected:(_)=>setState(()=>selectedFolderId=(folder['id'] as num).toInt())))])),
        if (folders.isNotEmpty) const SizedBox(height:10),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[for(final t in const ['all','img','pdf','doc','xls'])Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(t=='all'?'All types':t.toUpperCase()),selected:typeFilter==t,onSelected:(_)=>setState(()=>typeFilter=t)))])),
        const SizedBox(height:10),
        TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),labelText:'Search reports and documents')),const SizedBox(height:10),
        if(filtered.isEmpty)const EmptyRailway(title:'No files found',detail:'No active documents match the selected folder, type and search.'),
        if(filtered.isNotEmpty && (menu?['menuname']??'').toString().trim().toLowerCase() == 'my data')
          for(final f in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                title: Text((f['name']??'Untitled document').toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700)),
                subtitle:Text((f['type']??'FILE').toString().toUpperCase(),maxLines:1,overflow:TextOverflow.ellipsis),
                trailing:TextButton.icon(onPressed:()=>openDocument(f),icon:const Icon(Icons.open_in_new_rounded,size:18),label:const Text('Open')),
              ),
            ),
        if(filtered.isNotEmpty && (menu?['menuname']??'').toString().trim().toLowerCase() != 'my data')
          Card(clipBehavior:Clip.antiAlias,child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columnSpacing:22,columns:const [DataColumn(label:Text('Document')),DataColumn(label:Text('Type')),DataColumn(label:Text('Folder')),DataColumn(label:Text('Uploaded by')),DataColumn(label:Text('Uploaded at')),DataColumn(label:Text('Open'))],rows:filtered.map((f)=>DataRow(onSelectChanged:(_)=>showFile(f),cells:[DataCell(SizedBox(width:220,child:Text((f['name']??'Untitled document').toString(),maxLines:2,overflow:TextOverflow.ellipsis))),DataCell(Row(mainAxisSize:MainAxisSize.min,children:[fileIcon((f['type']??'').toString()),const SizedBox(width:6),Text((f['type']??'FILE').toString().toUpperCase())])),DataCell(Text((f['folder']??'—').toString())),DataCell(Text((f['uploaded_by']??'—').toString())),DataCell(Text((f['uploaded_at']??'—').toString())),DataCell(IconButton(tooltip:'Open details',onPressed:()=>showFile(f),icon:const Icon(Icons.open_in_new_rounded)))])).toList()))),
      ],
    ])));
  }

  Widget trackingContent(){
    final tabs=<({String id,String label,IconData icon})>[
      (id:'online',label:'Currently Online',icon:Icons.person_pin_circle_outlined),
      (id:'login',label:'Login History',icon:Icons.history_rounded),
      (id:'activity',label:'Page Activity',icon:Icons.timeline_rounded),
    ];
    final query=trackingSearch.trim().toLowerCase();
    final filteredRows=trackingRows.where((r)=>r.values.any((v)=>v!=null&&v.toString().toLowerCase().contains(query))).toList();
    final columns=trackingTab=='online'?<String>['username','email','role','last_activity_status']:trackingRows.isEmpty?<String>[]:trackingRows.first.keys.where((k)=>k!='id').map((k)=>k.toString()).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      hero('Manage Tracking','Monitor active users, login history and page activity.',Icons.monitor_heart_outlined),
      const SizedBox(height:16),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[for(final tab in tabs)Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(avatar:Icon(tab.icon,size:18),label:Text(tab.label),selected:trackingTab==tab.id,onSelected:(_)=>loadTracking(tab.id)))])),
      const SizedBox(height:12),
      TextField(onChanged:(v)=>setState(()=>trackingSearch=v),decoration:InputDecoration(prefixIcon:const Icon(Icons.search_rounded),labelText:trackingTab=='online'?'Search users':trackingTab=='login'?'Search login history':'Search page activity',suffixIcon:trackingSearch.isEmpty?null:IconButton(onPressed:()=>setState(()=>trackingSearch=''),icon:const Icon(Icons.clear_rounded)))),
      const SizedBox(height:8),
      if(busy)const LinearProgressIndicator(),
      if(!busy&&trackingRows.isEmpty)EmptyRailway(title:'No ${trackingTab=='online'?'online users':trackingTab=='login'?'login history':'page activity'} found',detail:'No records are available for this tab, or the current account cannot read its data.'),
      if(filteredRows.isNotEmpty)Card(clipBehavior:Clip.antiAlias,child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:columns.map((k)=>DataColumn(label:Text(k.replaceAll('_',' ').toUpperCase()))).toList(),rows:filteredRows.map((r)=>DataRow(cells:columns.map((k)=>DataCell(SizedBox(width:150,child:Text((r[k]??'—').toString(),maxLines:2,overflow:TextOverflow.ellipsis)))).toList())).toList()))),
    ]);
  }

  Widget hero(String title,String subtitle,IconData icon)=>DeckPageHero(title:title,subtitle:subtitle,icon:icon,gradientColors:const [Color(0xFF102D4D),Color(0xFF176B87)],iconColor:Colors.white,horizontal:true,padding:const EdgeInsets.all(22));
  Widget metric(String label,String value,IconData icon)=>DeckMetricCard(label:label,value:value,icon:icon,iconColor:const Color(0xFF1685A4),margin:EdgeInsets.zero);
  Icon fileIcon(String type){final t=type.toLowerCase();if(t.contains('pdf'))return const Icon(Icons.picture_as_pdf_rounded,color:Colors.redAccent);if(t.contains('xls')||t.contains('csv'))return const Icon(Icons.table_chart_rounded,color:Colors.green);if(t.contains('doc'))return const Icon(Icons.article_rounded,color:Colors.blue);if(t.contains('ppt'))return const Icon(Icons.slideshow_rounded,color:Colors.orange);if(['png','jpg','jpeg','gif','svg'].any(t.contains))return const Icon(Icons.image_outlined,color:Colors.purple);return const Icon(Icons.insert_drive_file_outlined);}
}

class EmptyRailway extends StatelessWidget {
  const EmptyRailway({super.key,required this.title,required this.detail});
  final String title,detail;
  @override Widget build(BuildContext context)=>DeckEmptyState(title:title,detail:detail,icon:Icons.folder_off_outlined);
}
