import 'dart:convert';
import 'package:flutter/material.dart';
import 'shared/widgets/deck_components.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _lhUrl = 'https://wrssvnvagpnvlwhnqqta.supabase.co';
const _lhKey = 'sb_publishable_AEu-JBRYrCLYrVq3VjAtyA_ya5ApyuM';
const _lhSessionKey = 'controldeck.lifehub.session.v1';
const _lhStorage = FlutterSecureStorage();
const _lhAccent = Color(0xFF8FA600);

class LifeHubFullNativeScreen extends StatefulWidget {
  const LifeHubFullNativeScreen({super.key});
  @override State<LifeHubFullNativeScreen> createState() => _LifeHubFullNativeScreenState();
}

class _LifeHubFullNativeScreenState extends State<LifeHubFullNativeScreen> {
  SupabaseClient? client;
  Map<String, dynamic>? profile, activeGroup;
  String? sessionId, error;
  bool loading = true, busy = false;
  int section = 0;
  String lifeTab = 'Tasks', financeTab = 'Transactions';
  List<Map<String, dynamic>> rows = [], groups = [], categories = [], members = [], groupExpenses = [], settlements = [];
  final search = TextEditingController();
  final lifeTabs = const ['Tasks','Notes','Goals','Reminders','Ideas'];
  final sections = const ['Dashboard','Life','Finance','Splitwise','Profile','Admin'];
  String get uid => (profile?['id'] ?? '').toString();
  bool get isAdmin => profile?['is_admin'] == true;

  @override void initState() { super.initState(); _restoreSession(); }
  @override void dispose() { search.dispose(); super.dispose(); }

  Future<Map<String, dynamic>> _exchangeLifeHubSession(String accessToken) async {
    final response = await Supabase.instance.client.functions.invoke(
      'controldeck-sso',
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'action': 'exchange', 'app': 'lifehub'},
    );
    if (response.data is! Map) throw Exception('LifeHub returned an invalid shared-session response.');
    final data = Map<String, dynamic>.from(response.data as Map);
    if (response.status >= 400 || data['error'] != null) {
      throw Exception((data['error'] ?? 'Could not open LifeHub with your ControlDeck session.').toString());
    }
    return data;
  }

  Future<void> _restoreSession() async {
    try {
      final auth = Supabase.instance.client.auth;
      var sharedSession = auth.currentSession;
      if (sharedSession == null) {
        try {
          final refreshed = await auth.refreshSession();
          sharedSession = refreshed.session ?? auth.currentSession;
        } catch (_) {
          sharedSession = auth.currentSession;
        }
      }
      if (sharedSession == null) {
        throw Exception('Your ControlDeck session is not available. Return to ControlDeck and sign in once; LifeHub will reuse that session.');
      }
      Map<String, dynamic> saved;
      try {
        saved = await _exchangeLifeHubSession(sharedSession.accessToken);
      } catch (e) {
        if (!e.toString().contains('401')) rethrow;
        final refreshed = await auth.refreshSession();
        sharedSession = refreshed.session ?? auth.currentSession;
        if (sharedSession == null) rethrow;
        saved = await _exchangeLifeHubSession(sharedSession.accessToken);
      }
      await _lhStorage.write(key: _lhSessionKey, value: jsonEncode(saved));
      final id = (saved['sessionId'] ?? '').toString();
      final p = Map<String,dynamic>.from(saved['profile'] as Map);
      if (id.isEmpty || p['id'] == null) throw Exception('LifeHub shared-session response was incomplete.');
      client = SupabaseClient(_lhUrl, _lhKey, headers: {'x-lifehub-session': id});
      try {
        final fullProfile = await client!.from('profiles').select('id,email,full_name,name,avatar,is_admin').eq('id', p['id']).maybeSingle();
        if (fullProfile != null) p.addAll(Map<String,dynamic>.from(fullProfile));
      } catch (_) {}
      if (!mounted) return;
      setState(() { sessionId = id; profile = p; loading = false; error = null; });
      await _loadCurrent();
    } catch (e) {
      if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; });
    }
  }

  String _lifeTable()=>switch(lifeTab){'Tasks'=>'tasks','Notes'=>'notes','Goals'=>'goals','Reminders'=>'reminders',_=>'ideas'};
  String _label(String t)=>switch(t){'tasks'=>'task','notes'=>'note','goals'=>'goal','reminders'=>'reminder','ideas'=>'idea','expenses'=>'transaction','budgets'=>'budget','expense_types'=>'category',_=>t};

  Future<void> _loadCurrent() async {
    if(client==null || uid.isEmpty) return;
    setState(()=>busy=true); error=null;
    try {
      if(section==0){
        final r=await Future.wait([
          client!.from('tasks').select('id').eq('user_id',uid),
          client!.from('goals').select('id').eq('user_id',uid),
          client!.from('ideas').select('id').eq('user_id',uid),
          client!.from('reminders').select('id').eq('user_id',uid).eq('done',false),
          client!.from('expenses').select('*').eq('user_id',uid),
        ]);
        rows=[{'kind':'Tasks','count':(r[0] as List).length},{'kind':'Goals','count':(r[1] as List).length},{'kind':'Ideas','count':(r[2] as List).length},{'kind':'Reminders','count':(r[3] as List).length},{'kind':'Transactions','count':(r[4] as List).length}];
      } else if(section==1){
        final t=_lifeTable(); var q=client!.from(t).select('*').eq('user_id',uid);
        final data=t=='notes'?await q.order('pinned',ascending:false).order('updated_at',ascending:false):await q.order('created_at',ascending:false);
        rows=(data as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
      } else if(section==2){
        final t=financeTab=='Budgets'?'budgets':'expenses';
        final data=await client!.from(t).select('*').eq('user_id',uid).order(t=='budgets'?'month':'date',ascending:false);
        rows=(data as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
      } else if(section==3){await _loadGroups();}
      else if(section==5 && isAdmin){
        final data=await client!.from('expense_types').select('*').order('kind').order('name');
        categories=(data as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
      }
    } catch(e){error=e.toString();}
    if(mounted) setState(()=>busy=false);
  }

  Future<void> _loadGroups() async {
    final data=await client!.from('sw_group_members').select('group_id, sw_groups(id,name,created_by,created_at)').eq('user_id',uid);
    groups=(data as List).map((e)=>Map<String,dynamic>.from(e as Map)['sw_groups']).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  }

  Future<void> _openGroup(Map<String,dynamic> group) async {
    setState(()=>busy=true); activeGroup=group;
    try {
      final r=await Future.wait([
        client!.from('sw_group_members').select('user_id, profiles(id,name,full_name,email,avatar)').eq('group_id',group['id']),
        client!.from('sw_expenses').select('*, sw_expense_shares(user_id,share_amount,settled)').eq('group_id',group['id']).order('date',ascending:false),
        client!.from('sw_settlements').select('*').eq('group_id',group['id']).order('created_at',ascending:false),
      ]);
      members=(r[0] as List).map((e)=>Map<String,dynamic>.from(e as Map)['profiles']).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      groupExpenses=(r[1] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
      settlements=(r[2] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
    } catch(e){error=e.toString();}
    if(mounted)setState(()=>busy=false);
  }

  Future<void> _showForm(String table,{Map<String,dynamic>? old}) async {
    final fields=switch(table){
      'tasks'=>[['title','Title',''],['description','Description','multi'],['priority','Priority: high/medium/low','medium'],['due_date','Due date YYYY-MM-DD','']],
      'notes'=>[['title','Title',''],['content','Content','multi'],['tags','Tags, comma separated',''],['color','Color hex','#f5a623']],
      'goals'=>[['title','Goal',''],['target','Target number','number'],['current','Current progress','number0'],['unit','Unit','%'],['deadline','Deadline YYYY-MM-DD','']],
      'reminders'=>[['title','Reminder',''],['remind_at','Date/time ISO 2026-10-31T18:00:00',''],['repeat_type','Repeat: none/daily/weekly/monthly','none']],
      'ideas'=>[['title','Idea',''],['description','Description','multi'],['tag','Tag: app/business/feature/general','general'],['priority','Priority: high/medium/low','medium']],
      'expenses'=>[['type','Type: income/expense','expense'],['amount','Amount in INR','number'],['category','Category',''],['description','Description',''],['date','Date YYYY-MM-DD',DateTime.now().toIso8601String().substring(0,10)]],
      'budgets'=>[['category','Category',''],['amount','Monthly limit in INR','number'],['month','Month YYYY-MM',DateTime.now().toIso8601String().substring(0,7)]],
      'expense_types'=>[['name','Category name',''],['kind','Kind: income/expense/both','both']],
      _=> <List<String>>[],
    };
    final controllers=<String,TextEditingController>{};
    for(final f in fields){final key=f[0]; final d=old?[key]?.toString()??(f[2]=='number0'?'0':f[2]=='number'?'':f[2]=='multi'?'':f[2]);controllers[key]=TextEditingController(text:d==''||d=='multi'||d=='number'||d=='number0'? '':d);}
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text((old==null?'Add ':'Edit ')+_label(table)),
      content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        for(final f in fields) Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:controllers[f[0]],minLines:f[2]=='multi'?2:1,maxLines:f[2]=='multi'?4:1,keyboardType:f[2]=='number'||f[2]=='number0'?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,decoration:InputDecoration(labelText:f[1]))),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))],
    ));
    if(ok==true){
      final payload=<String,dynamic>{};
      for(final f in fields){final key=f[0],value=controllers[key]!.text.trim(); if(f[2]=='number'||f[2]=='number0')payload[key]=num.tryParse(value)??0;else payload[key]=value.isEmpty?null:value;}
      if(table=='tasks')payload['status']=old?['status']??'pending';
      if(table=='notes'){payload['pinned']=old?['pinned']??false;payload['color']=payload['color']??'#f5a623';payload['updated_at']=DateTime.now().toUtc().toIso8601String();}
      if(table=='goals')payload['status']=old?['status']??'active';
      if(table=='reminders'){payload['done']=old?['done']??false;final v=payload['remind_at'];payload['remind_at']=v==null?null:(DateTime.tryParse(v.toString())?.toUtc().toIso8601String()??v);}
      if(table=='ideas')payload['status']=old?['status']??'new';
      if(table=='expenses' && payload['type']==null)payload['type']='expense';
      if(table=='budgets' && payload['month']==null)payload['month']=DateTime.now().toIso8601String().substring(0,7);
      if(table=='expense_types')payload['is_active']=old?['is_active']??true;
      if(table!='expense_types')payload['user_id']=uid;
      if(old?['id']!=null) await client!.from(table).update(payload).eq('id',old!['id']);
      else await client!.from(table).insert(payload);
      await _loadCurrent();
    }
    for(final c in controllers.values){c.dispose();}
  }

  Future<void> _delete(String table,Map<String,dynamic> row) async {
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Delete record?'),content:Text('Delete this '+_label(table)+'?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))]));
    if(yes!=true)return;
    await client!.from(table).delete().eq('id',row['id']);
    await _loadCurrent();
  }

  Future<void> _toggle(Map<String,dynamic> row,String table,String field,dynamic value) async {
    await client!.from(table).update({field:value}).eq('id',row['id']).eq('user_id',uid);
    await _loadCurrent();
  }

  Future<void> _createGroup() async {
    final name=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('New Splitwise group'),content:TextField(controller:name,decoration:const InputDecoration(labelText:'Group name')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Create'))]));
    if(ok!=true||name.text.trim().isEmpty)return;
    final g=await client!.from('sw_groups').insert({'name':name.text.trim(),'created_by':uid}).select().single();
    await client!.from('sw_group_members').insert({'group_id':g['id'],'user_id':uid});
    await _loadCurrent();
  }

  Future<void> _addGroupMember() async {
    if(activeGroup==null)return;
    final email=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Add member by email'),content:TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'LifeHub account email')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Add member'))]));
    if(ok!=true||email.text.trim().isEmpty)return;
    final found=await client!.from('profiles').select('id').ilike('email',email.text.trim()).maybeSingle();
    if(found==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No LifeHub profile found for that email.')));return;}
    if(found['id']==uid){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('You are already in this group.')));return;}
    final existing=await client!.from('sw_group_members').select('id').eq('group_id',activeGroup!['id']).eq('user_id',found['id']).maybeSingle();
    if(existing!=null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('That member is already in the group.')));return;}
    await client!.from('sw_group_members').insert({'group_id':activeGroup!['id'],'user_id':found['id']});
    await _openGroup(activeGroup!);
  }

  Future<void> _addExpense() async {
    if(activeGroup==null||members.isEmpty)return;
    final desc=TextEditingController(),amount=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Add shared expense'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:desc,decoration:const InputDecoration(labelText:'Description')),TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Amount INR'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))]));
    final value=num.tryParse(amount.text);
    if(ok!=true||value==null||value<=0)return;
    final exp=await client!.from('sw_expenses').insert({'group_id':activeGroup!['id'],'paid_by':uid,'description':desc.text.trim(),'amount':value,'category':'General','date':DateTime.now().toIso8601String().substring(0,10)}).select().single();
    final share=(value/members.length*100).round()/100;
    await client!.from('sw_expense_shares').insert(members.map((m)=>{'expense_id':exp['id'],'user_id':m['id'],'share_amount':share,'settled':m['id']==uid}).toList());
    await _openGroup(activeGroup!);
  }

  Future<void> _settle() async {
    if(activeGroup==null||members.length<2)return;
    final amount=TextEditingController(); String to=members.firstWhere((m)=>m['id']!=uid)['id'].toString();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:const Text('Settle up'),content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(value:to,decoration:const InputDecoration(labelText:'Paid to'),items:members.where((m)=>m['id']!=uid).map((m)=>DropdownMenuItem(value:m['id'].toString(),child:Text((m['name']??m['full_name']??m['email']??'Member').toString()))).toList(),onChanged:(v)=>setD(()=>to=v??to)),TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Amount INR'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Record'))])));
    final value=num.tryParse(amount.text);if(ok!=true||value==null||value<=0)return;
    await client!.from('sw_settlements').insert({'group_id':activeGroup!['id'],'from_user':uid,'to_user':to,'amount':value,'note':'Settlement'});
    await _openGroup(activeGroup!);
  }

  Future<void> _editProfile() async {
    final name=TextEditingController(text:(profile?['full_name']??profile?['name']??'').toString());String avatar=(profile?['avatar']??'🙂').toString();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:const Text('Edit profile'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Name')),DropdownButtonFormField<String>(value:avatar,decoration:const InputDecoration(labelText:'Avatar'),items:['🙂','😎','🧑‍💻','🧑‍🚀','🦊','🐼','🌟','🔥'].map((a)=>DropdownMenuItem(value:a,child:Text(a))).toList(),onChanged:(v)=>setD(()=>avatar=v??avatar))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))])));
    if(ok==true){await client!.from('profiles').update({'full_name':name.text.trim(),'name':name.text.trim(),'username':name.text.trim(),'avatar':avatar}).eq('id',uid);setState(()=>profile={...profile!,'full_name':name.text.trim(),'name':name.text.trim(),'avatar':avatar});}
  }

  Future<void> _changePassword() async {
    final current=TextEditingController(), next=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Change shared password'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:current,obscureText:true,decoration:const InputDecoration(labelText:'Current password')),TextField(controller:next,obscureText:true,decoration:const InputDecoration(labelText:'New password (at least 6 characters)'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Update password'))]));
    if(ok!=true)return;
    try {
      final auth=Supabase.instance.client.auth; final email=auth.currentUser?.email;
      if(email==null||next.text.length<6)throw Exception('Enter a new password with at least 6 characters.');
      await auth.signInWithPassword(email:email,password:current.text);
      await auth.updateUser(UserAttributes(password:next.text));
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Shared ControlDeck password updated.')));
    } catch(e) { if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ','')))); }
    current.dispose();next.dispose();
  }

  Future<void> _signOut() async {
    // Only ControlDeck's main account menu ends the shared login.
    if (mounted) Navigator.of(context).maybePop();
  }

  @override Widget build(BuildContext context) {
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(profile==null||client==null)return Scaffold(appBar:AppBar(title:const Text('LifeHub')),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.lock_outline_rounded,size:42),const SizedBox(height:12),Text(error??'Sign in to ControlDeck to access LifeHub.'),const SizedBox(height:12),FilledButton.icon(onPressed:_restoreSession,icon:const Icon(Icons.refresh),label:const Text('Retry shared sign-in'))]))));
    if(section==3&&activeGroup!=null)return Scaffold(appBar:AppBar(leading:IconButton(onPressed:()=>setState(()=>activeGroup=null),icon:const Icon(Icons.arrow_back)),title:Text(activeGroup!['name'].toString()),actions:[IconButton(tooltip:'Add member',onPressed:_addGroupMember,icon:const Icon(Icons.person_add_alt_1)),IconButton(onPressed:_addExpense,icon:const Icon(Icons.add_card)),IconButton(onPressed:_settle,icon:const Icon(Icons.payments_outlined))]),body:busy?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[_card(context,'Members',members.map((m)=>(m['avatar']??'🙂').toString()+' '+(m['name']??m['full_name']??m['email']??'Member').toString()).join('\n')),_card(context,'Balances',members.map((m){num net=0;for(final e in groupExpenses){if(e['paid_by']==m['id'])net+=num.tryParse(e['amount'].toString())??0;for(final sh in (e['sw_expense_shares'] as List? ?? const [])){if(sh['user_id']==m['id'])net-=num.tryParse(sh['share_amount'].toString())??0;}}for(final st in settlements){if(st['from_user']==m['id'])net+=num.tryParse(st['amount'].toString())??0;if(st['to_user']==m['id'])net-=num.tryParse(st['amount'].toString())??0;}final name=(m['name']??m['full_name']??m['email']??'Member').toString();return name+' · '+(net>=0?'is owed ':'owes ')+'₹'+net.abs().toStringAsFixed(2);}).join('\n')),_card(context,'Shared expenses',groupExpenses.isEmpty?'No expenses yet.':groupExpenses.map((e)=>(e['description']??'Expense').toString()+' · ₹'+e['amount'].toString()+' · '+e['date'].toString()).join('\n')),_card(context,'Settlements',settlements.isEmpty?'No settlements recorded.':settlements.map((e)=>'₹'+e['amount'].toString()+' · '+(e['note']??'Settlement').toString()).join('\n'))]));
    return Scaffold(
      appBar:AppBar(title:const Text('LifeHub',style:TextStyle(fontWeight:FontWeight.w800)),actions:[IconButton(tooltip:'Refresh',onPressed:_loadCurrent,icon:const Icon(Icons.refresh)),IconButton(tooltip:'Back to ControlDeck',onPressed:_signOut,icon:const Icon(Icons.arrow_back_rounded))]),
      body:Column(children:[
        if(error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
        SingleChildScrollView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),child:Row(children:[for(var i=0;i<sections.length;i++)if(i!=4&&(i!=5||isAdmin))Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:Text(sections[i]),selected:section==i,onSelected:(_){setState((){section=i;activeGroup=null;});_loadCurrent();}))])),
        if(section==1)SingleChildScrollView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:10),child:Row(children:[for(final t in lifeTabs)Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:Text(t),selected:lifeTab==t,onSelected:(_){setState(()=>lifeTab=t);_loadCurrent();}))])),
        if(section==2)Row(mainAxisAlignment:MainAxisAlignment.center,children:[for(final t in ['Transactions','Budgets','Reports'])Padding(padding:const EdgeInsets.all(4),child:ChoiceChip(label:Text(t),selected:financeTab==t,onSelected:(_){setState(()=>financeTab=t);_loadCurrent();}))]),
        Expanded(child:busy?const Center(child:CircularProgressIndicator()):_body(context)),
      ]),
      floatingActionButton:section==1||section==2||section==5&&isAdmin?FloatingActionButton.extended(onPressed:()=>_showForm(section==1?_lifeTable():section==2?(financeTab=='Budgets'?'budgets':'expenses'):'expense_types'),icon:const Icon(Icons.add),label:Text(section==1?'Add '+lifeTab:section==2?'Add '+financeTab:'Add category')):section==3?FloatingActionButton.extended(onPressed:_createGroup,icon:const Icon(Icons.group_add),label:const Text('New group')):null,
    );
  }

  Widget _body(BuildContext context){
    if(section==0){final income=rows.where((r)=>r['kind']=='Transactions').fold<num>(0,(s,r)=>s+(num.tryParse((r['count']??0).toString())??0));return ListView(padding:const EdgeInsets.all(16),children:[_hero(context,'Your life, organised.','Tasks, notes, goals, reminders, ideas, finance and shared expenses.',Icons.home_work_rounded),const SizedBox(height:14),LayoutBuilder(builder:(context,c)=>GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:c.maxWidth>700?3:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:2.2,children:rows.map((r)=>_metric(context,r['kind'].toString(),r['count'].toString())).toList())),const SizedBox(height:14)]);}
    if(section==4)return ListView(padding:const EdgeInsets.all(16),children:[_hero(context,'Your profile','Manage your LifeHub account details.',Icons.person),_card(context,'Name',(profile?['full_name']??profile?['name']??'').toString()),_card(context,'Email',(profile?['email']??'').toString()),const SizedBox(height:10),FilledButton.icon(onPressed:_editProfile,icon:const Icon(Icons.edit),label:const Text('Edit name and avatar')),const SizedBox(height:8),OutlinedButton.icon(onPressed:_changePassword,icon:const Icon(Icons.lock_reset_rounded),label:const Text('Change shared password')),OutlinedButton.icon(onPressed:_signOut,icon:const Icon(Icons.arrow_back_rounded),label:const Text('Back to ControlDeck'))]);
    if(section==3)return ListView(padding:const EdgeInsets.all(16),children:[_hero(context,'Splitwise','Create groups, split bills and record settlements.',Icons.people_alt),if(groups.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('No groups yet. Create one to start.')),for(final g in groups)Card(child:ListTile(leading:const Icon(Icons.groups),title:Text(g['name'].toString()),subtitle:const Text('Open shared expenses and settlements'),trailing:const Icon(Icons.chevron_right),onTap:()=>_openGroup(g)))]);
    if(section==5&&isAdmin)return ListView(padding:const EdgeInsets.all(16),children:[_hero(context,'Admin categories','Manage income and expense categories.',Icons.admin_panel_settings),for(final c in categories)Card(child:ListTile(title:Text(c['name'].toString()),subtitle:Text(c['kind'].toString()),trailing:Wrap(children:[IconButton(onPressed:()=>_showForm('expense_types',old:c),icon:const Icon(Icons.edit)),IconButton(onPressed:()=>_delete('expense_types',c),icon:const Icon(Icons.delete_outline))])))]);
    final table=section==1?_lifeTable():(financeTab=='Budgets'?'budgets':'expenses');
    final filtered=rows.where((r)=>search.text.trim().isEmpty||r.values.any((v)=>v.toString().toLowerCase().contains(search.text.trim().toLowerCase()))).toList();
    if(section==2&&financeTab=='Transactions'){final inc=rows.where((r)=>r['type']=='income').fold<num>(0,(s,r)=>s+(num.tryParse(r['amount'].toString())??0));final exp=rows.where((r)=>r['type']=='expense').fold<num>(0,(s,r)=>s+(num.tryParse(r['amount'].toString())??0));return ListView(padding:const EdgeInsets.all(16),children:[_hero(context,'Finance','Track income, expenses and budgets.',Icons.account_balance_wallet),Row(children:[Expanded(child:_metric(context,'Income','₹'+inc.toStringAsFixed(2))),Expanded(child:_metric(context,'Expenses','₹'+exp.toStringAsFixed(2))),]),_metric(context,'Net','₹'+(inc-exp).toStringAsFixed(2)),_searchBox(),for(final r in filtered)_record(context,r,table)]);}
    if(section==2&&financeTab=='Reports'){final inc=rows.where((r)=>r['type']=='income').fold<num>(0,(s,r)=>s+(num.tryParse(r['amount'].toString())??0));final exp=rows.where((r)=>r['type']=='expense').fold<num>(0,(s,r)=>s+(num.tryParse(r['amount'].toString())??0));final byCategory=<String,num>{};for(final r in rows.where((r)=>r['type']=='expense')){final k=(r['category']??'Other').toString();byCategory[k]=(byCategory[k]??0)+(num.tryParse(r['amount'].toString())??0);}return ListView(padding:const EdgeInsets.all(16),children:[_hero(context,'Financial reports','Income, expenses, net cash flow and spending by category.',Icons.query_stats_rounded),Row(children:[Expanded(child:_metric(context,'Income','₹'+inc.toStringAsFixed(2))),Expanded(child:_metric(context,'Expenses','₹'+exp.toStringAsFixed(2)))]),_metric(context,'Net cash flow','₹'+(inc-exp).toStringAsFixed(2)),_card(context,'Spending by category',byCategory.isEmpty?'No expense records yet.':byCategory.entries.map((e)=>e.key+' · ₹'+e.value.toStringAsFixed(2)).join('\\n')),_card(context,'Report scope','This report summarises all transactions currently available to your LifeHub profile. Use the Transactions tab to search, edit or remove individual entries.')]);}
    return ListView(padding:const EdgeInsets.all(16),children:[_hero(context,section==1?lifeTab:'Budgets',section==1?'Manage your '+lifeTab.toLowerCase()+'.':'Set and track monthly spending limits.',section==1?Icons.check_circle_outline:Icons.pie_chart_outline),_searchBox(),if(filtered.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('Nothing here yet. Use Add to create your first record.')),for(final r in filtered)_record(context,r,table)]);
  }

  Widget _record(BuildContext context,Map<String,dynamic> r,String table){final title=(r['title']??r['description']??r['category']??'Record').toString();final detail=r.entries.where((e)=>!['id','user_id','created_at','updated_at','title'].contains(e.key)&&e.value!=null&&e.value.toString().isNotEmpty).take(4).map((e)=>e.key.replaceAll('_',' ')+': '+e.value.toString()).join(' · ');return Card(margin:const EdgeInsets.only(bottom:5),child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),child:Row(children:[if(table=='tasks')Checkbox(value:r['status']=='done',onChanged:(v)=>_toggle(r,table,'status',v==true?'done':'pending'))else if(table=='notes')IconButton(onPressed:()=>_toggle(r,table,'pinned',r['pinned']!=true),icon:Icon(r['pinned']==true?Icons.push_pin:Icons.push_pin_outlined))else if(table=='reminders')Checkbox(value:r['done']==true,onChanged:(v)=>_toggle(r,table,'done',v==true))else if(table=='ideas')IconButton(onPressed:()=>_toggle(r,table,'status',r['status']=='new'?'wip':r['status']=='wip'?'done':r['status']=='done'?'shelved':'new'),icon:const Icon(Icons.autorenew))else const Icon(Icons.circle_outlined),const SizedBox(width:5),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:TextStyle(fontWeight:FontWeight.w700,decoration:r['status']=='done'||r['done']==true?TextDecoration.lineThrough:null)),if(detail.isNotEmpty)Text(detail,maxLines:3,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.bodySmall)])),IconButton(onPressed:()=>_showForm(table,old:r),icon:const Icon(Icons.edit_outlined,size:19)),IconButton(onPressed:()=>_delete(table,r),icon:const Icon(Icons.delete_outline,size:19))])));}
  Widget _searchBox()=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search this section…')));
}

Widget _hero(BuildContext c,String title,String subtitle,IconData icon)=>DeckPageHero(title:title,subtitle:subtitle,icon:icon,iconColor:_lhAccent);
Widget _metric(BuildContext c,String label,String value)=>DeckMetricCard(label:label,value:value,margin:EdgeInsets.zero);
Widget _card(BuildContext c,String title,String body)=>DeckInfoCard(title:title,body:body);
