import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Native Flutter version of Railways Admin > User Profiles.
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
  bool get isAdmin => (widget.user['role'] ?? '').toString().toLowerCase() == 'admin';

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
      final hm = <int,List<String>>{}, mm = <int,List<String>>{};
      for (final row in results[3] as List) {
        final id = (row['user_id'] as num).toInt();
        final name = row['main_heading_master']?['headingname']?.toString();
        if (name != null && name.isNotEmpty) (hm[id] ??= []).add(name);
      }
      for (final row in results[4] as List) {
        final id = (row['user_id'] as num).toInt();
        final name = row['menu_master']?['menuname']?.toString();
        if (name != null && name.isNotEmpty) (mm[id] ??= []).add(name);
      }
      if (!mounted) return;
      setState(() {
        users=loadedUsers; headings=loadedHeadings; menus=loadedMenus;
        headingNames=hm; menuNames=mm;
        if (page > totalPages) page = totalPages;
      });
    } catch (e) {
      if (mounted) setState(() => error = _friendly(e));
    } finally { if (mounted) setState(() => busy = false); }
  }

  String _friendly(Object e) {
    final s=e.toString().replaceFirst('Exception: ','');
    if (s.toLowerCase().contains('row-level security') || s.toLowerCase().contains('permission denied')) return 'Access denied by the Railways database policy.';
    return s;
  }

  List<Map<String,dynamic>> get filtered {
    final q=search.trim().toLowerCase();
    return users.where((u) {
      final r=(u['role']??'user').toString().toLowerCase();
      final hay=['username','email','dept','project'].map((k)=>(u[k]??'').toString().toLowerCase()).join(' ');
      return (q.isEmpty || hay.contains(q)) && (roleFilter=='all' || r==roleFilter);
    }).toList();
  }
  int get totalPages => (filtered.length/pageSize).ceil().clamp(1, 999999);
  List<Map<String,dynamic>> get shown => filtered.skip((page-1)*pageSize).take(pageSize).toList();

  Future<void> openForm([Map<String,dynamic>? old]) async {
    if (!isAdmin || saving) return;
    final wasEditing=old!=null;
    editId=old==null?null:(old['id'] as num).toInt();
    username.text=(old?['username']??'').toString();
    email.text=(old?['email']??'').toString();
    dept.text=(old?['dept']??'').toString();
    password.clear();
    final oldRole=(old?['role']??'user').toString().toLowerCase();
    role=['admin','subadmin','user'].contains(oldRole)?oldRole:'user';
    selectedHeadings=[]; selectedMenus=[];
    if(editId!=null) {
      try {
        final h=await widget.db.from('user_main_heading_access').select('main_heading_id').eq('user_id',editId!);
        final m=await widget.db.from('user_menu_access').select('menu_id').eq('user_id',editId!);
        selectedHeadings=h.map<int>((x)=>(x['main_heading_id'] as num).toInt()).toList();
        selectedMenus=m.map<int>((x)=>(x['menu_id'] as num).toInt()).toList();
      } catch(e) { if(mounted)setState(()=>error=_friendly(e)); return; }
    }
    if(!mounted)return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialog) {
            final formFields = <Widget>[
              TextFormField(
                controller: username,
                decoration: const InputDecoration(labelText: 'Username *'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Username is required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Email is required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(labelText: wasEditing ? 'New password (optional)' : 'Password *'),
                validator: (v) => !wasEditing && (v ?? '').trim().isEmpty ? 'Password is required' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'subadmin', child: Text('SubAdmin')),
                  DropdownMenuItem(value: 'user', child: Text('User')),
                ],
                onChanged: (v) => setDialog(() => role = v ?? 'user'),
              ),
              const SizedBox(height: 8),
              TextFormField(controller: dept, decoration: const InputDecoration(labelText: 'Department')),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Main Heading Access', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              for (final h in headings)
                Builder(builder: (context) {
                  final headingId = (h['id'] as num).toInt();
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text((h['headingname'] ?? '').toString()),
                    value: selectedHeadings.contains(headingId),
                    onChanged: (checked) => setDialog(() {
                      if (checked == true) {
                        if (!selectedHeadings.contains(headingId)) selectedHeadings.add(headingId);
                        for (final menu in menus.where((m) => (m['main_heading_id'] as num).toInt() == headingId)) {
                          final menuId = (menu['id'] as num).toInt();
                          if (!selectedMenus.contains(menuId)) selectedMenus.add(menuId);
                        }
                      } else {
                        selectedHeadings.remove(headingId);
                        final menuIds = menus
                            .where((m) => (m['main_heading_id'] as num).toInt() == headingId)
                            .map((m) => (m['id'] as num).toInt())
                            .toSet();
                        selectedMenus.removeWhere(menuIds.contains);
                      }
                    }),
                  );
                }),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Menu Access', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              for (final h in headings) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text((h['headingname'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                for (final menu in menus.where((m) => (m['main_heading_id'] as num).toInt() == (h['id'] as num).toInt()))
                  CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 12),
                    title: Text((menu['menuname'] ?? '').toString()),
                    value: selectedMenus.contains((menu['id'] as num).toInt()),
                    onChanged: selectedHeadings.contains((h['id'] as num).toInt())
                        ? (checked) => setDialog(() {
                              final menuId = (menu['id'] as num).toInt();
                              if (checked == true) {
                                if (!selectedMenus.contains(menuId)) selectedMenus.add(menuId);
                              } else {
                                selectedMenus.remove(menuId);
                              }
                            })
                        : null,
                  ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Project / Main Heading Access: ${selectedHeadings.isEmpty ? (role == 'admin' ? 'All Main Headings' : 'None assigned') : headings.where((h) => selectedHeadings.contains((h['id'] as num).toInt())).map((h) => h['headingname']).join(', ')}',
                ),
              ),
            ];
            return AlertDialog(
              title: Text(wasEditing ? 'Edit User Profile' : 'Add User Profile'),
              content: SizedBox(
                width: 640,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 620),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(mainAxisSize: MainAxisSize.min, children: formFields),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx, true),
                  child: Text(wasEditing ? 'Update User' : 'Add User'),
                ),
              ],
            );
          },
        );
      },
    );
    if(accepted!=true)return;
    if(!(formKey.currentState?.validate()??false)) { if(mounted) setState(()=>error='Please complete the required fields.'); return; }
    setState(()=>saving=true);
    try {
      final duplicate=await widget.db.from('users').select('id').eq('username',username.text.trim()).maybeSingle();
      if(duplicate!=null && (editId==null || duplicate['id'].toString()!=editId.toString())) throw Exception('This username already exists.');
      final project=selectedHeadings.isEmpty?(role=='admin'?'All Main Headings':''):headings.where((h)=>selectedHeadings.contains((h['id'] as num).toInt())).map((h)=>h['headingname']).join(', ');
      final data=<String,dynamic>{'username':username.text.trim(),'role':role=='admin'?'Admin':role=='subadmin'?'SubAdmin':'User','email':email.text.trim(),'dept':dept.text.trim(),'project':project};
      if(password.text.trim().isNotEmpty)data['password']=password.text.trim();
      dynamic saved;
      if(editId==null) {
        data['password']=password.text.trim();
        saved=await widget.db.from('users').insert(data).select('id').single();
      } else {
        saved=await widget.db.from('users').update(data).eq('id',editId!).select('id').single();
      }
      final id=saved['id'];
      await widget.db.from('user_main_heading_access').delete().eq('user_id',id);
      if(selectedHeadings.isNotEmpty) await widget.db.from('user_main_heading_access').insert(selectedHeadings.map((v)=>{'user_id':id,'main_heading_id':v,'created_by':widget.user['username']}).toList());
      await widget.db.from('user_menu_access').delete().eq('user_id',id);
      if(selectedMenus.isNotEmpty) await widget.db.from('user_menu_access').insert(selectedMenus.map((v)=>{'user_id':id,'menu_id':v,'created_by':widget.user['username']}).toList());
      if(mounted)setState(()=>notice=wasEditing?'User updated successfully.':'User added successfully.');
      await load();
    } catch(e) { if(mounted)setState(()=>error=_friendly(e)); }
    finally { if(mounted)setState(()=>saving=false); }
  }

  Future<void> deleteUser(Map<String,dynamic> u) async {
    final id=u['id'];
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Delete user?'),content:Text('Delete ${u['username']} and its access assignments?'),actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete')),
    ]));
    if(ok!=true)return;
    try {
      await widget.db.from('user_main_heading_access').delete().eq('user_id',id);
      await widget.db.from('user_menu_access').delete().eq('user_id',id);
      await widget.db.from('users').delete().eq('id',id);
      if(mounted)setState(()=>notice='User deleted successfully.');
      await load();
    } catch(e) { if(mounted)setState(()=>error=_friendly(e)); }
  }

  Future<void> export(String mode) async {
    const headers=['ID','Username','Email','Role','Department','Project'];
    final rows=filtered.map((u)=>[u['id'],u['username']??'',u['email']??'',u['role']??'',u['dept']??'',u['project']??'']);
    if(mode=='Copy to clipboard') {
      await Clipboard.setData(ClipboardData(text:[headers,...rows].map((r)=>r.map((v)=>v.toString().replaceAll('\t',' ')).join('\t')).join('\n')));
      if(mounted)setState(()=>notice='User data copied to clipboard.');
    } else {
      final csv=[headers,...rows].map((r)=>r.map((v)=>'"${v.toString().replaceAll('"','""')}"').join(',')).join('\r\n');
      await Clipboard.setData(ClipboardData(text:csv));
      if(mounted)setState(()=>notice='Export data copied as CSV. Paste it into a spreadsheet and save as ${mode=='Export as Excel'?'Excel':'CSV'}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if(!isAdmin)return const Center(child:Card(child:Padding(padding:EdgeInsets.all(24),child:Text('Access Denied. Only administrators can manage user profiles.'))));
    final rows=filtered, totalPagesSafe=totalPages, current=page.clamp(1,totalPages);
    final visible=shown, start=rows.isEmpty?0:(current-1)*pageSize+1, end=(current*pageSize).clamp(0,rows.length);
    final adminCount=users.where((u)=>(u['role']??'').toString().toLowerCase()=='admin').length;
    final subCount=users.where((u)=>(u['role']??'').toString().toLowerCase()=='subadmin').length;
    return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[
      if(error!=null)_message(error!,true),
      if(notice!=null)_message(notice!,false),
      LayoutBuilder(builder:(ctx,c){final compact=c.maxWidth<420;return GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:3,childAspectRatio:compact?0.92:c.maxWidth<650?1.35:2.8,mainAxisSpacing:6,crossAxisSpacing:6,children:[
        _stat('Total Users',users.length,Icons.people_outline,Colors.blue),
        _stat('Administrators',adminCount,Icons.admin_panel_settings_outlined,Colors.red),
        _stat('Users',users.length-adminCount-subCount,Icons.person_outline,Colors.green),
      ]);}),
      const SizedBox(height:14),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('All Users',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
        const SizedBox(height:12),
        LayoutBuilder(builder:(ctx,c)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search users...',border:OutlineInputBorder(),isDense:true),onChanged:(v)=>setState((){search=v;page=1;})),
          const SizedBox(height:8),
          Row(children:[
            Expanded(flex:3,child:SizedBox(height:48,child:DropdownButtonFormField<String>(value:roleFilter,decoration:const InputDecoration(labelText:'Role',border:OutlineInputBorder(),isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:12,vertical:10)),isExpanded:true,items:const [DropdownMenuItem(value:'all',child:Text('All')),DropdownMenuItem(value:'admin',child:Text('Admin')),DropdownMenuItem(value:'subadmin',child:Text('SubAdmin')),DropdownMenuItem(value:'user',child:Text('Users'))],onChanged:(v)=>setState((){roleFilter=v??'all';page=1;})))),
            const SizedBox(width:6),
            Expanded(flex:4,child:SizedBox(height:48,child:PopupMenuButton<String>(onSelected:export,itemBuilder:(_)=>const [PopupMenuItem(value:'Copy to clipboard',child:Text('Copy to clipboard')),PopupMenuItem(value:'Export as Excel',child:Text('Export as Excel')),PopupMenuItem(value:'Export as CSV',child:Text('Export as CSV'))],child:Container(height:48,padding:const EdgeInsets.symmetric(horizontal:10),decoration:BoxDecoration(border:Border.all(color:Theme.of(ctx).colorScheme.outline),borderRadius:BorderRadius.circular(8)),child:const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.file_download_outlined,size:18),SizedBox(width:4),Flexible(child:Text('Export Report',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:13)))]))))),
            const SizedBox(width:6),
            Expanded(flex:3,child:FilledButton.icon(style:FilledButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:6),minimumSize:const Size(0,48)),onPressed:()=>openForm(),icon:const Icon(Icons.add,size:18),label:const FittedBox(fit:BoxFit.scaleDown,child:Text('Add User')))),
          ]),
        ])),
        const SizedBox(height:12),
        if(busy)const LinearProgressIndicator(),
        if(!busy && visible.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Center(child:Text('No users found.'))),
        if(!busy && visible.isNotEmpty)SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:const [
          DataColumn(label:Text('#')),DataColumn(label:Text('User')),DataColumn(label:Text('Email')),DataColumn(label:Text('Role')),DataColumn(label:Text('Department')),DataColumn(label:Text('Main Heading Access')),DataColumn(label:Text('Menu Access')),DataColumn(label:Text('Action')),
        ],rows:[
          for(var i=0;i<visible.length;i++) DataRow(cells:[
            DataCell(Text('${(current-1)*pageSize+i+1}')),
            DataCell(SizedBox(width:145,child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text((visible[i]['username']??'—').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),Text('ID: ${visible[i]['id']}',style:Theme.of(context).textTheme.bodySmall)]))),
            DataCell(Text((visible[i]['email']??'—').toString())),
            DataCell(_role((visible[i]['role']??'User').toString())),
            DataCell(Text((visible[i]['dept']??'—').toString())),
            DataCell(_chips(headingNames[(visible[i]['id'] as num).toInt()]??const [])),
            DataCell(_chips(menuNames[(visible[i]['id'] as num).toInt()]??const [])),
            DataCell(Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:'Edit profile',onPressed:()=>openForm(visible[i]),icon:const Icon(Icons.edit_outlined)),IconButton(tooltip:'Delete user',onPressed:()=>deleteUser(visible[i]),icon:const Icon(Icons.delete_outline,color:Colors.red))])),
          ])
        ])),
        if(!busy&&rows.isNotEmpty)Padding(padding:const EdgeInsets.only(top:14),child:Wrap(alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,spacing:10,runSpacing:10,children:[
          Text('Showing $start to $end of ${rows.length} users'),
          Wrap(crossAxisAlignment:WrapCrossAlignment.center,spacing:8,children:[
            const Text('Rows per page:'),
            DropdownButton<int>(value:pageSize,items:const [10,20,50,100,500].map((n)=>DropdownMenuItem(value:n,child:Text('$n'))).toList(),onChanged:(v)=>setState((){pageSize=v??10;page=1;})),
            IconButton(tooltip:'Previous page',onPressed:current>1?()=>setState(()=>page=current-1):null,icon:const Icon(Icons.chevron_left)),
            Text('$current / $totalPagesSafe'),
            IconButton(tooltip:'Next page',onPressed:current<totalPagesSafe?()=>setState(()=>page=current+1):null,icon:const Icon(Icons.chevron_right)),
          ]),
        ])),
      ]))),
    ]));
  }

  Widget _message(String value,bool bad)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Material(color:(bad?Colors.red:Colors.green).withOpacity(.08),borderRadius:BorderRadius.circular(10),child:ListTile(leading:Icon(bad?Icons.error_outline:Icons.check_circle_outline,color:bad?Colors.red:Colors.green),title:Text(value),trailing:IconButton(onPressed:()=>setState(()=>bad?error=null:notice=null),icon:const Icon(Icons.close)))));
  Widget _stat(String label,int value,IconData icon,Color color)=>Card(child:LayoutBuilder(builder:(ctx,c){final compact=c.maxWidth<135;return Padding(padding:EdgeInsets.all(compact?6:16),child:compact?Column(mainAxisAlignment:MainAxisAlignment.center,children:[CircleAvatar(radius:15,backgroundColor:color.withOpacity(.12),child:Icon(icon,color:color,size:17)),const SizedBox(height:5),FittedBox(fit:BoxFit.scaleDown,child:Text('$value',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800))),Text(label,textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w600))]):Row(children:[CircleAvatar(backgroundColor:color.withOpacity(.12),child:Icon(icon,color:color)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$value',style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800)),Text(label)]))]));}));
  Widget _role(String value){final r=value.toLowerCase();final color=r=='admin'?Colors.red:r=='subadmin'?Colors.orange:Colors.green;return Chip(label:Text(r=='admin'?'Admin':r=='subadmin'?'SubAdmin':'User'),backgroundColor:color.withOpacity(.12),side:BorderSide.none);}
  Widget _chips(List<String> values)=>SizedBox(width:210,child:values.isEmpty?const Text('—'):Wrap(spacing:4,runSpacing:2,children:values.map((v)=>Chip(label:Text(v,style:const TextStyle(fontSize:11)),visualDensity:VisualDensity.compact)).toList()));
}
