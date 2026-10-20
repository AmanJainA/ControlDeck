import 'package:flutter/material.dart';
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
  late final SupabaseClient db;
  final username = TextEditingController(), password = TextEditingController(), search = TextEditingController();
  Map<String,dynamic>? user, heading, menu;
  List<Map<String,dynamic>> headings=[], menus=[], files=[];
  bool busy=false, reveal=false;
  String view='login';
  String? error;
  bool get admin => (user?['role']??'').toString().toLowerCase()=='admin';

  @override void initState(){super.initState();db=SupabaseClient(SupabaseConfig.professionalUrl,SupabaseConfig.professionalKey);}
  @override void dispose(){username.dispose();password.dispose();search.dispose();db.dispose();super.dispose();}

  String message(Object e){
    final s=e.toString().replaceFirst('Exception: ','');
    if(s.contains('Failed to fetch')||s.contains('SocketException'))return 'Cannot connect. Check your internet connection.';
    if(s.contains('permission denied')||s.contains('row-level security'))return 'Access denied by the Railway database policy.';
    return s;
  }

  Future<void> login() async {
    if(username.text.trim().isEmpty||password.text.isEmpty){setState(()=>error='Enter your Railway username and password.');return;}
    setState(() { busy = true; error = null; });
    try{
      final row=await db.from('users').select('id,username,email,role,dept,project')
        .eq('username',username.text.trim()).eq('password',password.text).maybeSingle();
      if(row==null)throw Exception('Invalid username or password.');
      if(!mounted)return;
      setState(() { user = Map<String,dynamic>.from(row); password.clear(); view = 'home'; });
      await loadHeadings();
    }catch(e){if(mounted)setState(()=>error=message(e));}
    finally{if(mounted)setState(()=>busy=false);}
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
      if(mounted)setState(() { menus = result; });
    }catch(e){if(mounted)setState(()=>error=message(e));}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> openMenu(Map<String,dynamic> m) async {
    setState(() { menu = m; view = 'files'; files = []; search.clear(); busy = true; error = null; });
    try{
      final rows=await db.from('datacollection').select('id,name,type,links,menuname,folder,folder_id,menu_id,status,remark,uploaded_by,uploaded_at')
        .eq('menu_id',m['id']).eq('status',1).order('id',ascending:false);
      if(mounted)setState(() { files = List<Map<String,dynamic>>.from(rows); });
    }catch(e){if(mounted)setState(()=>error=message(e));}
    finally{if(mounted)setState(()=>busy=false);}
  }


  Future<void> uploadLink() async {
    final title = TextEditingController();
    final link = TextEditingController();
    int? headingId = headings.isEmpty ? null : (headings.first['id'] as num).toInt();
    int? menuId;
    List<Map<String,dynamic>> availableMenus = [];
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
            headingId = v; menuId = null; availableMenus = [];
            if (v != null) {
              final raw = await db.from('menu_master').select('id,menuname').eq('main_heading_id', v).eq('status', '1').order('id');
              availableMenus = List<Map<String,dynamic>>.from(raw);
            }
            setDialog(() {});
          }),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(value: menuId, decoration: const InputDecoration(labelText: 'Menu'),
          items: availableMenus.map((m) => DropdownMenuItem<int>(value: (m['id'] as num).toInt(), child: Text((m['menuname'] ?? '').toString()))).toList(),
          onChanged: (v) => setDialog(() => menuId = v)),
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
        await db.from('datacollection').insert({
          'name': title.text.trim(), 'links': storedLink, 'type': type, 'menuname': selectedMenu['menuname'],
          'main_heading_id': headingId, 'menu_id': menuId, 'status': 0, 'uploaded_by': user?['username'],
          'uploaded_at': DateTime.now().toIso8601String(), 'source_type': sourceType,
        });
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

  Future<void> openMyData() async {
    setState(() { menu = {'menuname':'My Data'}; heading = null; view = 'files'; files = []; search.clear(); busy = true; error = null; });
    try{
      final rows=await db.from('datacollection').select('id,name,type,links,menuname,folder,folder_id,menu_id,status,remark,uploaded_by,uploaded_at')
        .eq('menuname','mydata').order('id',ascending:false);
      if(mounted)setState(() { files = List<Map<String,dynamic>>.from(rows); });
    }catch(e){if(mounted)setState(()=>error=message(e));}
    finally{if(mounted)setState(()=>busy=false);}
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
    if(view=='files'||view=='menus'){setState(() { view = 'home'; heading = null; menu = null; });return;}
    Navigator.of(context).maybePop();
  }

  Future<void> showFile(Map<String,dynamic> f) async {
    final link=(f['links']??'').toString().trim();
    await showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,builder:(ctx)=>SafeArea(child:Padding(
      padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text((f['name']??'Document').toString(),style:Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
        const SizedBox(height:14),
        detail('Type',(f['type']??'Unknown').toString()),
        detail('Folder',(f['folder']??'—').toString()),
        detail('Uploaded by',(f['uploaded_by']??'—').toString()),
        detail('Uploaded at',(f['uploaded_at']??'—').toString()),
        if((f['remark']??'').toString().isNotEmpty)detail('Remark',f['remark'].toString()),
        const SizedBox(height:16),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:link.isEmpty?null:()async{
          final uri=Uri.tryParse(link);
          if(uri==null||!await launchUrl(uri,mode:LaunchMode.platformDefault)){
            if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('Could not open this document link.')));
          }
        },icon:const Icon(Icons.open_in_new_rounded),label:const Text('Open document'))),
        const SizedBox(height:8),Text('File details are displayed in Flutter. The linked document opens in a supported viewer.',style:Theme.of(ctx).textTheme.bodySmall),
      ]))));
  }

  Widget detail(String k,String v)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Row(children:[
    SizedBox(width:105,child:Text(k,style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant))),Expanded(child:SelectableText(v))
  ]));

  @override Widget build(BuildContext context){
    final title=view=='files'?(menu?['menuname']??'Files').toString():view=='menus'?(heading?['headingname']??'Workspace').toString():'Railways';
    return Scaffold(appBar:AppBar(
      leading:IconButton(onPressed:user==null?()=>Navigator.of(context).maybePop():back,icon:const Icon(Icons.arrow_back_rounded)),
      title:Text(title),
      actions:[
        if(user!=null)IconButton(tooltip:'Refresh',onPressed:view=='files'?(heading==null?openMyData:()=>openMenu(menu!)):view=='menus'?()=>openHeading(heading!):loadHeadings,icon:const Icon(Icons.refresh_rounded)),
        if(user!=null)IconButton(tooltip:'Sign out',onPressed:()=>setState(() { user = null; headings = []; menus = []; files = []; view = 'login'; error = null; }),icon:const Icon(Icons.logout_rounded)),
      ],
    ),body:user==null?loginView():workspaceView());
  }

  Widget loginView()=>Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(24),children:[
    Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(colors:[Color(0xFF102D4D),Color(0xFF176B87)])),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(Icons.train_rounded,size:42,color:Colors.white),SizedBox(height:14),
      Text('Railway workspace',style:TextStyle(fontSize:25,color:Colors.white,fontWeight:FontWeight.w800)),
      SizedBox(height:6),Text('Native Flutter access to railway workspaces and documents.',style:TextStyle(color:Colors.white70)),
    ])),
    const SizedBox(height:22),
    TextField(controller:username,textInputAction:TextInputAction.next,decoration:const InputDecoration(labelText:'Railway username',prefixIcon:Icon(Icons.person_outline_rounded))),
    const SizedBox(height:12),
    TextField(controller:password,obscureText:!reveal,onSubmitted:(_)=>login(),decoration:InputDecoration(labelText:'Password',prefixIcon:const Icon(Icons.lock_outline_rounded),suffixIcon:IconButton(onPressed:()=>setState(()=>reveal=!reveal),icon:Icon(reveal?Icons.visibility_off_rounded:Icons.visibility_rounded)))),
    if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    const SizedBox(height:18),
    FilledButton.icon(onPressed:busy?null:login,icon:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.login_rounded),label:Text(busy?'Signing in…':'Sign in to Railways')),
    const SizedBox(height:10),Text('Uses your existing Railway portal credentials. Password is not saved in ControlDeck.',textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall),
  ])));

  Widget workspaceView(){
    if(busy)return const Center(child:CircularProgressIndicator());
    final filtered=files.where((f)=>'${f['name']??''} ${f['type']??''} ${f['folder']??''}'.toLowerCase().contains(search.text.toLowerCase())).toList();
    return Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1100),child:ListView(padding:const EdgeInsets.all(20),children:[
      if(error!=null)Card(color:Theme.of(context).colorScheme.errorContainer,child:Padding(padding:const EdgeInsets.all(14),child:Text(error!))),
      if(view=='home')...[
        hero('Welcome, ${user?['username']??'Railway user'}','${user?['dept']??'Railway workspace'} · ${user?['role']??'User'}',Icons.train_rounded),
        const SizedBox(height:16),
        LayoutBuilder(builder:(ctx,c){final cols=c.maxWidth>700?3:c.maxWidth>460?2:1;return GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:cols,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:cols==1?4:2.3,children:[
          metric('Workspaces',headings.length.toString(),Icons.account_tree_rounded),metric('Role',(user?['role']??'User').toString(),Icons.verified_user_outlined),metric('Project',(user?['project']??'Railways').toString(),Icons.business_center_outlined)
        ]);}),
        const SizedBox(height:18),
        Row(children:[Expanded(child:Text('Workspaces',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800))),TextButton.icon(onPressed:openMyData,icon:const Icon(Icons.folder_copy_outlined),label:const Text('My Data'))]),
        if(headings.isEmpty)const EmptyRailway(title:'No workspaces assigned',detail:'Ask your administrator to grant access.'),
        for(final h in headings)Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.account_tree_rounded)),title:Text((h['headingname']??'Workspace').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:const Text('Open menus and documents'),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>openHeading(h))),
        const SizedBox(height:20),
        Text('Railway tools', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height:8),
        Card(child: ListTile(leading: const Icon(Icons.cloud_upload_outlined), title: const Text('Upload Files'), subtitle: const Text('Submit a document or cloud link'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => uploadLink())),
        Card(child: ListTile(leading: const Icon(Icons.folder_copy_outlined), title: const Text('My Data'), subtitle: const Text('View your submissions'), trailing: const Icon(Icons.chevron_right_rounded), onTap: openMyData)),
        if (canApprove) Card(child: ListTile(leading: const Icon(Icons.fact_check_outlined), title: const Text('Pending Approvals'), subtitle: const Text('Approve or reject submitted files'), trailing: const Icon(Icons.chevron_right_rounded), onTap: openPendingApprovals)),
        if (admin) ...[
          Card(child: ListTile(leading: const Icon(Icons.file_present_outlined), title: const Text('Manage Uploads'), subtitle: const Text('Edit or delete document metadata'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => openNativeManager('datacollection', 'Manage Uploads'))),
          Card(child: ListTile(leading: const Icon(Icons.account_tree_outlined), title: const Text('Main Headings'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => openNativeManager('main_heading_master', 'Main Headings'))),
          Card(child: ListTile(leading: const Icon(Icons.menu_open_rounded), title: const Text('Manage Menus'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => openNativeManager('menu_master', 'Manage Menus'))),
          Card(child: ListTile(leading: const Icon(Icons.folder_outlined), title: const Text('Manage Folders'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => openNativeManager('folder_master', 'Manage Folders'))),
          Card(child: ListTile(leading: const Icon(Icons.manage_accounts_outlined), title: const Text('Users & Access'), subtitle: const Text('Manage Railway accounts'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => openNativeManager('users', 'Users & Access'))),
          Card(child: ListTile(leading: const Icon(Icons.task_alt_rounded), title: const Text('Work Tracker'), subtitle: const Text('Manage tasks, reports and due dates'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => openNativeManager('work_items', 'Work Tracker'))),
          Card(child: ListTile(leading: const Icon(Icons.monitor_heart_outlined), title: const Text('User Presence'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => openNativeManager('user_presence', 'User Presence'))),
        ],
      ]else if(view=='pending')...[
        hero('Pending Approvals', 'Approve or reject documents submitted by Railway users.', Icons.fact_check_outlined),
        if (files.isEmpty) const EmptyRailway(title: 'No pending documents', detail: 'There are no submissions waiting for approval.'),
        for (final f in files) Card(child: ListTile(
          leading: fileIcon((f['type'] ?? '').toString()),
          title: Text((f['name'] ?? 'Document').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Uploaded by: ' + (f['uploaded_by'] ?? 'Unknown').toString() + '\\n' + (f['menuname'] ?? '').toString() + ' • ' + (f['uploaded_at'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'approve') updateApproval(f, 1); if (v == 'reject') updateApproval(f, 2); }, itemBuilder: (_) => const [
            PopupMenuItem(value: 'approve', child: Text('Approve')),
            PopupMenuItem(value: 'reject', child: Text('Reject')),
          ]),
          onTap: () => showFile(f),
        )),
      ]else if(view=='menus')...[
        hero((heading?['headingname']??'Workspace').toString(),'Choose a menu to browse its files.',Icons.folder_open_rounded),const SizedBox(height:14),
        if(menus.isEmpty)const EmptyRailway(title:'No menus available',detail:'No active menus or access grants were found.'),
        for(final m in menus)Card(child:ListTile(leading:const Icon(Icons.folder_copy_outlined),title:Text((m['menuname']??'Menu').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>openMenu(m))),
      ]else...[
        hero((menu?['menuname']??'Files').toString(),'${filtered.length} records · native Flutter list',Icons.description_outlined),const SizedBox(height:14),
        TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),labelText:'Search documents')),const SizedBox(height:10),
        if(filtered.isEmpty)const EmptyRailway(title:'No files found',detail:'No active documents match this menu and search.'),
        for(final f in filtered)Card(child:ListTile(leading:fileIcon((f['type']??'').toString()),title:Text((f['name']??'Untitled document').toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${(f['type']??'FILE').toString().toUpperCase()} · ${(f['folder']??'No folder').toString()}\\n${(f['uploaded_by']??'Uploader unknown').toString()}',maxLines:2,overflow:TextOverflow.ellipsis),isThreeLine:true,trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>showFile(f))),
      ],
    ])));
  }

  Widget hero(String title,String subtitle,IconData icon)=>Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(colors:[Color(0xFF102D4D),Color(0xFF176B87)])),child:Row(children:[
    Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.13),borderRadius:BorderRadius.circular(14)),child:Icon(icon,color:Colors.white,size:30)),const SizedBox(width:14),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:5),Text(subtitle,style:const TextStyle(color:Colors.white70))]))
  ]));
  Widget metric(String label,String value,IconData icon)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[Icon(icon,color:const Color(0xFF1685A4),size:28),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:Theme.of(context).textTheme.bodySmall),const SizedBox(height:4),Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800))]))])));
  Icon fileIcon(String type){final t=type.toLowerCase();if(t.contains('pdf'))return const Icon(Icons.picture_as_pdf_rounded,color:Colors.redAccent);if(t.contains('xls')||t.contains('csv'))return const Icon(Icons.table_chart_rounded,color:Colors.green);if(t.contains('doc'))return const Icon(Icons.article_rounded,color:Colors.blue);if(t.contains('ppt'))return const Icon(Icons.slideshow_rounded,color:Colors.orange);if(['png','jpg','jpeg','gif','svg'].any(t.contains))return const Icon(Icons.image_outlined,color:Colors.purple);return const Icon(Icons.insert_drive_file_outlined);}
}

class EmptyRailway extends StatelessWidget {
  const EmptyRailway({super.key,required this.title,required this.detail});
  final String title,detail;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:32,horizontal:12),child:Column(children:[
    Icon(Icons.folder_off_outlined,size:40,color:Theme.of(context).colorScheme.onSurfaceVariant),const SizedBox(height:12),
    Text(title,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:6),
    Text(detail,textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodyMedium?.copyWith(color:Theme.of(context).colorScheme.onSurfaceVariant)),
  ]));
}
