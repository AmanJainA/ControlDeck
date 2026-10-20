import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _notesSessionKey = 'controldeck.notes.session.v1';
const _notesAdminEmail = 'amanjain033@gmail.com';

/// Native Notes app: curriculum, lesson blocks, progress, contact and admin tools.
class NotesFullNativeScreen extends StatefulWidget {
  const NotesFullNativeScreen({super.key});
  @override State<NotesFullNativeScreen> createState() => _NotesFullNativeScreenState();
}
class _NotesFullNativeScreenState extends State<NotesFullNativeScreen> {
  static const storage = FlutterSecureStorage();
  SupabaseClient? publicClient, client;
  bool busy = false, loading = false, signUpMode = false;
  String page = 'Dashboard', query = '';
  String? error, notice, token;
  Map<String,dynamic>? profile, language, topic;
  List<Map<String,dynamic>> languages = [], topics = [], progress = [], profiles = [];
  List<dynamic> blocks = [];
  final email = TextEditingController(text: _notesAdminEmail);
  final password = TextEditingController();
  final name = TextEditingController();
  final search = TextEditingController();
  final contactName = TextEditingController();
  final contactEmail = TextEditingController(text: _notesAdminEmail);
  final contactSubject = TextEditingController();
  final contactMessage = TextEditingController();

  bool get isAdmin => profile?['email']?.toString().toLowerCase() == _notesAdminEmail;
  @override void initState() {
    super.initState();
    if (_notesUrl.isNotEmpty && _notesKey.isNotEmpty) {
      publicClient = SupabaseClient(_notesUrl, _notesKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false, persistSession: false));
      client = publicClient;
      restore();
    }
  }
  @override void dispose() {
    for (final c in [email,password,name,search,contactName,contactEmail,contactSubject,contactMessage]) { c.dispose(); }
    super.dispose();
  }
  String friendly(Object e) => e.toString().replaceFirst('Exception: ', '');
  void applySession(String t, Map<String,dynamic> p) {
    token=t; profile=p;
    client=SupabaseClient(_notesUrl,_notesKey,headers:{'Authorization':'Bearer $t'},
      authOptions: const AuthClientOptions(autoRefreshToken:false,persistSession:false));
  }
  Future<Map<String,dynamic>> authCall(String action, Map<String,dynamic> payload) async {
    final response=await publicClient!.functions.invoke('custom-auth',body:{'action':action,'app':'notes',...payload});
    if (response.status>=400 || response.data is! Map || response.data['error']!=null) {
      throw Exception(response.data is Map ? (response.data['error'] ?? response.data['message'] ?? 'Authentication failed').toString() : 'Authentication failed.');
    }
    return Map<String,dynamic>.from(response.data as Map);
  }
  Future<void> restore() async {
    try {
      final raw=await storage.read(key:_notesSessionKey);
      if(raw!=null && raw.isNotEmpty) {
        final saved=Map<String,dynamic>.from(jsonDecode(raw) as Map);
        if(DateTime.now().millisecondsSinceEpoch < (saved['expiresAt'] as num? ?? 0)) {
          applySession(saved['token'].toString(),Map<String,dynamic>.from(saved['profile'] as Map));
          contactEmail.text=profile?['email']?.toString() ?? _notesAdminEmail;
          await loadProgress();
        } else { await storage.delete(key:_notesSessionKey); }
      }
    } catch(e) { if(mounted) setState(()=>error=friendly(e)); }
    await loadLanguages();
  }
  Future<void> submitAuth() async {
    if(publicClient==null) return;
    if(email.text.trim().isEmpty || password.text.isEmpty || (signUpMode && password.text.length<8)) {
      setState(()=>error=signUpMode?'Enter email and a password of at least 8 characters.':'Enter email and password.'); return;
    }
    setState(()=>{busy=true,error=null,notice=null});
    try {
      final data=await authCall(signUpMode?'signup':'login',{'email':email.text.trim().toLowerCase(),'password':password.text,if(signUpMode)'name':name.text.trim()});
      if(signUpMode) {
        setState(()=>{notice='Account request submitted. Check your email if verification is enabled, then sign in.',signUpMode=false});
      } else {
        final t=data['token']?.toString(); final p=data['profile'];
        if(t==null || t.isEmpty || p is! Map) throw Exception('Notes sign-in returned an incomplete session.');
        final seconds=(data['expiresIn'] as num?)?.toInt() ?? 3600;
        await storage.write(key:_notesSessionKey,value:jsonEncode({'token':t,'expiresAt':DateTime.now().millisecondsSinceEpoch+seconds*1000,'profile':p}));
        applySession(t,Map<String,dynamic>.from(p));
        contactEmail.text=profile?['email']?.toString() ?? _notesAdminEmail;
        await loadLanguages(); await loadProgress();
      }
    } catch(e) { if(mounted)setState(()=>error=friendly(e)); }
    finally { if(mounted)setState(()=>busy=false); }
  }
  Future<void> forgotPassword() async {
    if(email.text.trim().isEmpty){setState(()=>error='Enter your email first.');return;}
    setState(()=>{busy=true,error=null,notice=null});
    try { await authCall('request_reset',{'email':email.text.trim().toLowerCase()}); if(mounted)setState(()=>notice='If the account exists, password-reset instructions have been sent.'); }
    catch(e){if(mounted)setState(()=>error=friendly(e));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> signOut() async {
    await storage.delete(key:_notesSessionKey);
    if(mounted)setState(()=>{token=null,profile=null,client=publicClient,language=null,topic=null,blocks=[],progress=[],page='Dashboard',notice='Signed out of Notes.'});
  }
  Future<void> loadLanguages() async {
    if(client==null)return;
    setState(()=>{loading=true,error=null});
    try { final rows=await client!.schema('notes').from('languages').select('*').order('sort_order').order('name'); if(mounted)languages=List<Map<String,dynamic>>.from(rows); }
    catch(e){if(mounted)setState(()=>error=friendly(e));}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> loadTopics(Map<String,dynamic> item) async {
    setState(()=>{language=item,topic=null,blocks=[],loading=true,error=null});
    try { final rows=await client!.schema('notes').from('topics').select('*').eq('language_id',item['id']).order('sort_order').order('title'); if(mounted)setState(()=>{topics=List<Map<String,dynamic>>.from(rows),page='Lessons'}); }
    catch(e){if(mounted)setState(()=>error=friendly(e));}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> loadLesson(Map<String,dynamic> item) async {
    setState(()=>{topic=item,blocks=[],loading=true,error=null});
    try { final row=await client!.schema('notes').from('topic_content').select('content').eq('topic_id',item['id']).maybeSingle(); if(mounted)setState(()=>{blocks=List<dynamic>.from(row?['content'] as List? ?? const []),page='Lesson'}); }
    catch(e){if(mounted)setState(()=>error=friendly(e));}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> loadProgress() async {
    if(token==null || profile==null)return;
    try { final rows=await client!.schema('notes').from('user_progress').select('id,topic_id,completed,completed_at').eq('user_id',profile!['id']).order('completed_at',ascending:false); if(mounted)setState(()=>progress=List<Map<String,dynamic>>.from(rows)); } catch(_){}
  }
  bool completed(String id)=>progress.any((p)=>p['topic_id'].toString()==id && p['completed']==true);
  Future<void> toggleProgress() async {
    if(token==null || profile==null || topic==null){setState(()=>notice='Sign in to save lesson progress.');return;}
    final id=topic!['id'].toString(); final matches=progress.where((p)=>p['topic_id'].toString()==id).toList(); final done=!completed(id);
    try {
      if(matches.isEmpty) await client!.schema('notes').from('user_progress').insert({'user_id':profile!['id'],'topic_id':id,'completed':true,'completed_at':DateTime.now().toIso8601String()});
      else await client!.schema('notes').from('user_progress').update({'completed':done,'completed_at':done?DateTime.now().toIso8601String():null}).eq('id',matches.first['id']).eq('user_id',profile!['id']);
      await loadProgress();
    }catch(e){if(mounted)setState(()=>error=friendly(e));}
  }
  Future<void> sendContact() async {
    if(contactName.text.trim().isEmpty || contactEmail.text.trim().isEmpty || contactMessage.text.trim().isEmpty){setState(()=>error='Name, email and message are required.');return;}
    try {
      await client!.schema('notes').from('contact_messages').insert({'user_id':profile?['id'],'name':contactName.text.trim(),'email':contactEmail.text.trim(),'subject':contactSubject.text.trim(),'message':contactMessage.text.trim()});
      contactSubject.clear();contactMessage.clear();if(mounted)setState(()=>notice='Message sent. Thanks for reaching out.');
    }catch(e){if(mounted)setState(()=>error=friendly(e));}
  }
  Future<void> loadAdmin() async {
    if(!isAdmin){setState(()=>error='Admin access is restricted.');return;}
    setState(()=>{loading=true,error=null});
    try {
      final result=await Future.wait([
        client!.schema('notes').from('profiles').select('id,email,full_name,created_at').order('created_at',ascending:false),
        client!.schema('notes').from('topics').select('*').order('sort_order'),
      ]);
      if(mounted)setState(()=>{profiles=List<Map<String,dynamic>>.from(result[0]),topics=List<Map<String,dynamic>>.from(result[1]),page='Admin'});
    }catch(e){if(mounted)setState(()=>error=friendly(e));}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> editLanguage([Map<String,dynamic>? old]) async {
    if(!isAdmin)return;
    final n=TextEditingController(text:old?['name']?.toString()??''); final s=TextEditingController(text:old?['slug']?.toString()??'');
    final d=TextEditingController(text:old?['description']?.toString()??''); final o=TextEditingController(text:old?['sort_order']?.toString()??'0');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(old==null?'Add language':'Edit language'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:n,decoration:const InputDecoration(labelText:'Name')),TextField(controller:s,decoration:const InputDecoration(labelText:'Slug')),
      TextField(controller:d,decoration:const InputDecoration(labelText:'Description')),TextField(controller:o,decoration:const InputDecoration(labelText:'Sort order')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))]));
    if(ok==true)try{
      final row={'name':n.text.trim(),'slug':s.text.trim().toLowerCase(),'description':d.text.trim(),'icon':'fas fa-code','sort_order':int.tryParse(o.text)??0};
      if(old==null)await client!.schema('notes').from('languages').insert(row);else await client!.schema('notes').from('languages').update(row).eq('id',old['id']);
      await loadLanguages();
    }catch(e){if(mounted)setState(()=>error=friendly(e));}
    for(final c in [n,s,d,o]){c.dispose();}
  }
  Future<void> editTopic([Map<String,dynamic>? old]) async {
    if(!isAdmin || languages.isEmpty)return;
    String languageId=old?['language_id']?.toString()??languages.first['id'].toString();
    final t=TextEditingController(text:old?['title']?.toString()??'');final s=TextEditingController(text:old?['slug']?.toString()??'');final o=TextEditingController(text:old?['sort_order']?.toString()??'0');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(title:Text(old==null?'Add topic':'Edit topic'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<String>(value:languageId,items:languages.map((l)=>DropdownMenuItem(value:l['id'].toString(),child:Text(l['name'].toString()))).toList(),onChanged:(v)=>setDialog(()=>languageId=v??languageId),decoration:const InputDecoration(labelText:'Language')),
      TextField(controller:t,decoration:const InputDecoration(labelText:'Topic title')),TextField(controller:s,decoration:const InputDecoration(labelText:'Slug')),TextField(controller:o,decoration:const InputDecoration(labelText:'Sort order')),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))])));
    if(ok==true)try{
      final row={'language_id':languageId,'title':t.text.trim(),'slug':s.text.trim().toLowerCase(),'sort_order':int.tryParse(o.text)??0};
      if(old==null)await client!.schema('notes').from('topics').insert(row);else await client!.schema('notes').from('topics').update(row).eq('id',old['id']);
      await loadTopics(language??languages.first);
    }catch(e){if(mounted)setState(()=>error=friendly(e));}
    for(final c in [t,s,o]){c.dispose();}
  }
  Future<void> editContent(Map<String,dynamic> item) async {
    if(!isAdmin)return;
    try{
      final row=await client!.schema('notes').from('topic_content').select('content').eq('topic_id',item['id']).maybeSingle();
      final c=TextEditingController(text:const JsonEncoder.withIndent('  ').convert(row?['content']??[]));
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('Lesson JSON · ${item['title']}'),content:SizedBox(width:700,child:TextField(controller:c,minLines:10,maxLines:20,style:const TextStyle(fontFamily:'monospace'),decoration:const InputDecoration(helperText:'JSON array: heading, subheading, paragraph, code, list, image, note, table, divider'))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))]));
      if(ok==true){final parsed=jsonDecode(c.text);if(parsed is! List)throw Exception('Lesson content must be a JSON array.');await client!.schema('notes').from('topic_content').upsert({'topic_id':item['id'],'content':parsed,'updated_at':DateTime.now().toIso8601String()},onConflict:'topic_id');if(mounted)setState(()=>notice='Lesson content saved.');}
      c.dispose();
    }catch(e){if(mounted)setState(()=>error=friendly(e));}
  }
  Future<void> deleteRow(String table,Map<String,dynamic> row) async {
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('Delete ${row['title']??row['name']}?'),content:const Text('This action cannot be undone.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))]));
    if(ok!=true)return;
    try{await client!.schema('notes').from(table).delete().eq('id',row['id']);if(table=='languages')await loadLanguages();else await loadTopics(language??languages.first);}
    catch(e){if(mounted)setState(()=>error=friendly(e));}
  }
  @override Widget build(BuildContext context) {
    final ready=publicClient!=null; final theme=Theme.of(context);
    return Scaffold(appBar:AppBar(leading:IconButton(onPressed:(){if(topic!=null)setState(()=>{topic=null,blocks=[],page='Lessons'});else if(language!=null)setState(()=>{language=null,page='Dashboard'});else Navigator.of(context).maybePop();},icon:const Icon(Icons.arrow_back_rounded)),title:const Text('Notes'),actions:[
      if(profile!=null)IconButton(tooltip:'Profile',onPressed:()=>setState(()=>page='Profile'),icon:const Icon(Icons.account_circle_outlined)),
      if(profile!=null)IconButton(tooltip:'Sign out',onPressed:signOut,icon:const Icon(Icons.logout_rounded)),const SizedBox(width:8)]),
      body:!ready?const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Configure NOTES_SUPABASE_URL and NOTES_SUPABASE_ANON_KEY to connect your Notes Supabase project.'))):
      profile==null?authView(theme):loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(18),children:[
        if(error!=null)message(error!,true),if(notice!=null)message(notice!,false),
        if(page=='Dashboard')...dashboard(theme),if(page=='Lessons')...lessonList(theme),if(page=='Lesson')...lessonView(theme),
        if(page=='About')...aboutView(),if(page=='Contact')...contactView(),if(page=='Profile')...profileView(theme),if(page=='Admin')...adminView(theme),
      ]);
  }
  Widget authView(ThemeData theme)=>Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:470),child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(22),children:[
    const _NotesHero(title:'Coding Notes',subtitle:'Programming lessons, learning progress and resources in one place.'),
    if(signUpMode)TextField(controller:name,decoration:const InputDecoration(labelText:'Full name')),
    const SizedBox(height:12),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email')),
    const SizedBox(height:10),TextField(controller:password,obscureText:true,onSubmitted:(_)=>submitAuth(),decoration:InputDecoration(labelText:'Password',helperText:signUpMode?'At least 8 characters':null)),
    if(error!=null)message(error!,true),if(notice!=null)message(notice!,false),
    const SizedBox(height:14),FilledButton(onPressed:busy?null:submitAuth,child:busy?const CircularProgressIndicator():Text(signUpMode?'Create Notes account':'Sign in')),
    if(!signUpMode)TextButton(onPressed:forgotPassword,child:const Text('Forgot password?')),
    TextButton(onPressed:()=>setState(()=>{signUpMode=!signUpMode,error=null,notice=null}),child:Text(signUpMode?'Already registered? Sign in':'Create account')),
  ])));
  List<Widget> dashboard(ThemeData theme){
    final q=query.toLowerCase();final visible=languages.where((l)=>q.isEmpty||[l['name'],l['description'],l['slug']].any((v)=>(v??'').toString().toLowerCase().contains(q))).toList();
    return [const _NotesHero(title:'Coding Notes',subtitle:'Database-driven coding notes for BCA/MCA students.'),
      Row(children:[Expanded(child:Text('${languages.length} languages',style:theme.textTheme.titleMedium)),Text('${progress.where((p)=>p['completed']==true).length} completed')]),
      TextField(controller:search,onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(labelText:'Search languages',prefixIcon:Icon(Icons.search_rounded))),
      Wrap(spacing:8,children:[
        ActionChip(label:const Text('About'),onPressed:()=>setState(()=>page='About')),
        ActionChip(label:const Text('Contact'),onPressed:()=>setState(()=>page='Contact')),
        if(isAdmin)ActionChip(label:const Text('Admin management'),onPressed:loadAdmin),
      ]),
      LayoutBuilder(builder:(context,box){final cols=box.maxWidth>760?3:box.maxWidth>460?2:1;return GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:cols,mainAxisSpacing:12,crossAxisSpacing:12,childAspectRatio:cols==1?2.6:1.6,children:visible.map((l)=>Card(child:InkWell(onTap:()=>loadTopics(l),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Icon(Icons.code_rounded,color:Colors.amber,size:30),const Spacer(),Text(l['name'].toString(),style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
        Text(l['description']?.toString()??'',maxLines:3,overflow:TextOverflow.ellipsis),const SizedBox(height:8),const Text('Open curriculum →'),
      ]))))).toList());})];
  }
  List<Widget> lessonList(ThemeData theme)=>[
    _NotesHero(title:language?['name']?.toString()??'Lessons',subtitle:language?['description']?.toString()??'Select a lesson.'),
    Row(children:[Expanded(child:Text('${topics.length} lessons')),if(isAdmin)FilledButton.tonalIcon(onPressed:()=>editTopic(),icon:const Icon(Icons.add),label:const Text('Add topic'))]),
    for(final t in topics)Card(child:ListTile(leading:Icon(completed(t['id'].toString())?Icons.check_circle:Icons.menu_book_rounded),title:Text(t['title'].toString()),subtitle:Text(completed(t['id'].toString())?'Completed':'Lesson'),trailing:Wrap(mainAxisSize:MainAxisSize.min,children:[
      if(isAdmin)IconButton(onPressed:()=>editTopic(t),icon:const Icon(Icons.edit_outlined)),if(isAdmin)IconButton(onPressed:()=>editContent(t),icon:const Icon(Icons.edit_note_rounded)),const Icon(Icons.chevron_right_rounded),
    ]),onTap:()=>loadLesson(t))),
  ];
  List<Widget> lessonView(ThemeData theme)=>[
    _NotesHero(title:topic?['title']?.toString()??'Lesson',subtitle:language?['name']?.toString()??'Programming'),
    Wrap(spacing:8,children:[FilledButton.tonalIcon(onPressed:toggleProgress,icon:Icon(completed(topic?['id']?.toString()??'')?Icons.check_circle:Icons.check_circle_outline),label:Text(completed(topic?['id']?.toString()??'')?'Mark incomplete':'Mark complete')),if(isAdmin)OutlinedButton.icon(onPressed:()=>editContent(topic!),icon:const Icon(Icons.edit_note),label:const Text('Edit lesson'))]),
    if(blocks.isEmpty)const _NotesNotice(title:'No lesson content yet',detail:'This topic has no content blocks in the database yet.'),for(final b in blocks)if(b is Map)_NotesBlock(block:Map<String,dynamic>.from(b)),
  ];
  List<Widget> aboutView()=>[const _NotesHero(title:'About Notes',subtitle:'Reusable, database-driven coding notes for BCA/MCA students.'),const _NotesNotice(title:'Learn by language and topic',detail:'Supported subjects include C, C++, Java, PHP, HTML, CSS, JavaScript and Bootstrap. New tracks and lessons load from Supabase.')];
  List<Widget> contactView()=>[const _NotesHero(title:'Contact',subtitle:'Send a question or feedback message.'),TextField(controller:contactName,decoration:const InputDecoration(labelText:'Name *')),TextField(controller:contactEmail,decoration:const InputDecoration(labelText:'Email *')),TextField(controller:contactSubject,decoration:const InputDecoration(labelText:'Subject')),TextField(controller:contactMessage,minLines:4,maxLines:8,decoration:const InputDecoration(labelText:'Message *')),const SizedBox(height:10),FilledButton.icon(onPressed:sendContact,icon:const Icon(Icons.send),label:const Text('Send message'))];
  List<Widget> profileView(ThemeData theme)=>[const _NotesHero(title:'My Notes profile',subtitle:'Account and learning progress.'),Card(child:ListTile(leading:const Icon(Icons.account_circle),title:Text(profile?['full_name']?.toString()??profile?['name']?.toString()??'Notes user'),subtitle:Text(profile?['email']?.toString()??''))),Text('${progress.where((p)=>p['completed']==true).length} lessons completed'),FilledButton.tonalIcon(onPressed:changePassword,icon:const Icon(Icons.password),label:const Text('Change password')),OutlinedButton.icon(onPressed:signOut,icon:const Icon(Icons.logout),label:const Text('Sign out'))];
  Future<void> changePassword() async {
    final current=TextEditingController(),next=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Change password'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:current,obscureText:true,decoration:const InputDecoration(labelText:'Current password')),TextField(controller:next,obscureText:true,decoration:const InputDecoration(labelText:'New password'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Update'))]));
    if(ok==true)try{await authCall('change_password',{'currentPassword':current.text,'newPassword':next.text});if(mounted)setState(()=>notice='Password updated.');}catch(e){if(mounted)setState(()=>error=friendly(e));}
    current.dispose();next.dispose();
  }
  List<Widget> adminView(ThemeData theme)=>[
    _NotesHero(title:'Notes Admin Management',subtitle:'Manage curriculum, lesson content and profiles.'),
    Row(children:[Expanded(child:Text('Languages',style:theme.textTheme.titleLarge)),FilledButton.icon(onPressed:()=>editLanguage(),icon:const Icon(Icons.add),label:const Text('Add'))]),
    for(final l in languages)Card(child:ListTile(title:Text(l['name'].toString()),subtitle:Text('${l['slug']} · order ${l['sort_order']}'),trailing:Wrap(children:[IconButton(onPressed:()=>editLanguage(l),icon:const Icon(Icons.edit_outlined)),IconButton(onPressed:()=>deleteRow('languages',l),icon:const Icon(Icons.delete_outline))]))),
    Row(children:[Expanded(child:Text('Topics',style:theme.textTheme.titleLarge)),FilledButton.icon(onPressed:()=>editTopic(),icon:const Icon(Icons.add),label:const Text('Add'))]),
    for(final t in topics)Card(child:ListTile(title:Text(t['title'].toString()),trailing:Wrap(children:[IconButton(onPressed:()=>editTopic(t),icon:const Icon(Icons.edit_outlined)),IconButton(onPressed:()=>editContent(t),icon:const Icon(Icons.edit_note)),IconButton(onPressed:()=>deleteRow('topics',t),icon:const Icon(Icons.delete_outline))]))),
    Text('Profiles',style:theme.textTheme.titleLarge),for(final p in profiles)Card(child:ListTile(title:Text(p['full_name']?.toString()??'Unnamed user'),subtitle:Text(p['email']?.toString()??''))),
    const _NotesNotice(title:'Database policy required',detail:'Admin writes are enforced by Supabase RLS. Apply docs/NOTES_ADMIN_POLICIES.sql in the Notes project before using admin edit controls.'),
  ];
  Widget message(String text,bool isError)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:(isError?Theme.of(context).colorScheme.error:Colors.green).withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),child:Text(text,style:TextStyle(color:isError?Theme.of(context).colorScheme.error:Colors.green)));
}

class _NotesHero extends StatelessWidget {
  const _NotesHero({required this.title,required this.subtitle});
  final String title,subtitle;
  @override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:LinearGradient(colors:[Colors.amber.withValues(alpha:.18),Theme.of(context).colorScheme.surfaceContainerHighest])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.menu_book_rounded,color:Colors.amber,size:32),const SizedBox(height:14),Text(title,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:8),Text(subtitle,style:Theme.of(context).textTheme.bodyLarge)]));
}
class _NotesNotice extends StatelessWidget {
  const _NotesNotice({required this.title,required this.detail});
  final String title,detail;
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(detail,style:Theme.of(context).textTheme.bodyMedium?.copyWith(height:1.45))])));
}
class _NotesBlock extends StatelessWidget {
  const _NotesBlock({required this.block});
  final Map<String,dynamic> block;
  @override Widget build(BuildContext context) {
    final theme=Theme.of(context);final type=(block['type']??'').toString();final text=(block['text']??block['content']??block['title']??'').toString();
    if(type=='heading')return Padding(padding:const EdgeInsets.only(top:18,bottom:8),child:Text(text,style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)));
    if(type=='subheading')return Padding(padding:const EdgeInsets.only(top:12,bottom:6),child:Text(text,style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700)));
    if(type=='code')return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[if((block['filename']??'').toString().isNotEmpty)Text(block['filename'].toString()),const SizedBox(height:8),SingleChildScrollView(scrollDirection:Axis.horizontal,child:SelectableText((block['code']??text).toString(),style:const TextStyle(fontFamily:'monospace',height:1.5)))])));
    if(type=='list'){final items=List<dynamic>.from(block['items'] as List? ?? const []);return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[for(var i=0;i<items.length;i++)Padding(padding:const EdgeInsets.only(bottom:7),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:24,child:Text(block['ordered']==true?'${i+1}.':'•',style:const TextStyle(color:Colors.amber,fontWeight:FontWeight.w800))),Expanded(child:Text(items[i] is Map?(items[i]['text']??'').toString():items[i].toString()))]))])));}
    if(type=='image'){final src=(block['src']??'').toString();if(src.isEmpty)return const SizedBox.shrink();return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Image.network(src,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined)),if((block['caption']??'').toString().isNotEmpty)Text(block['caption'].toString())])));}
    if(type=='table'){final headers=List<dynamic>.from(block['headers'] as List? ?? const []);final rows=List<dynamic>.from(block['rows'] as List? ?? const []);if(headers.isEmpty)return const SizedBox.shrink();return Card(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:headers.map((h)=>DataColumn(label:Text(h.toString()))).toList(),rows:rows.map((r){final cells=List<dynamic>.from(r as List);return DataRow(cells:List.generate(headers.length,(i)=>DataCell(Text(i<cells.length?cells[i].toString():''))));}).toList())));}
    if(type=='divider')return const Divider(height:28);
    if(type=='note'){final v=(block['variant']??'info').toString();final color=v=='warning'?Colors.orange:v=='tip'?Colors.green:Colors.amber;return Card(color:color.withValues(alpha:.12),child:Padding(padding:const EdgeInsets.all(14),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(v=='warning'?Icons.warning_amber_rounded:v=='tip'?Icons.lightbulb_outline_rounded:Icons.info_outline_rounded,color:color),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[if((block['title']??'').toString().isNotEmpty)Text(block['title'].toString(),style:const TextStyle(fontWeight:FontWeight.w800)),Text(text)]))])));}
    return Padding(padding:const EdgeInsets.symmetric(vertical:7),child:SelectableText(text,style:theme.textTheme.bodyLarge?.copyWith(height:1.55)));
  }
}
