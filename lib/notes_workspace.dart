import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const controlDeckWorkspaceUrl = String.fromEnvironment('SUPABASE_URL');
const controlDeckWorkspaceKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const notesWorkspaceUrl = String.fromEnvironment('NOTES_SUPABASE_URL', defaultValue: String.fromEnvironment('SUPABASE_URL'));
const notesWorkspaceKey = String.fromEnvironment('NOTES_SUPABASE_ANON_KEY', defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'));
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
  String page = 'Home', query = '';
  String? error, notice, token;
  Map<String,dynamic>? profile, language, topic;
  List<Map<String,dynamic>> languages = [], topics = [], allTopics = [], progress = [], profiles = [], onlineUsers = [], loginActivity = [], pageVisits = [];
  String activityTab = 'Online';
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
    if (notesWorkspaceUrl.isNotEmpty && notesWorkspaceKey.isNotEmpty) {
      publicClient = SupabaseClient(notesWorkspaceUrl, notesWorkspaceKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false));
      client = publicClient;
      if (usesSharedControlDeckAuth) {
        initializeSharedNotes();
      } else {
        restore();
      }
    }
  }
  bool get usesSharedControlDeckAuth =>
      notesWorkspaceUrl == controlDeckWorkspaceUrl &&
      controlDeckWorkspaceUrl.isNotEmpty &&
      controlDeckWorkspaceKey.isNotEmpty;

  Future<Map<String, dynamic>> _requestSharedNotes(String accessToken) async {
    final response = await Supabase.instance.client.functions.invoke(
      'controldeck-sso',
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'app': 'notes', 'page': '/'},
    );
    if (response.data is! Map) {
      throw Exception('Notes access could not be verified.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    if (response.status >= 400 || data['error'] != null) {
      throw Exception((data['error'] ?? 'Notes access could not be verified.').toString());
    }
    return data;
  }

  Future<void> initializeSharedNotes() async {
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;
    if (session == null) {
      try {
        final refreshed = await auth.refreshSession();
        session = refreshed.session ?? auth.currentSession;
      } catch (_) {
        session = auth.currentSession;
      }
    }
    if (session == null) {
      if (mounted) setState(() {
        loading = false;
        error = 'Your ControlDeck session is unavailable. Return to ControlDeck and sign in once; Notes will reuse that session.';
      });
      return;
    }
    setState(() => {loading = true, error = null, notice = null});
    try {
      Map<String, dynamic> data;
      try {
        data = await _requestSharedNotes(session.accessToken);
      } catch (e) {
        // Supabase Flutter throws FunctionsHttpException for HTTP 401 instead
        // of always returning a response object. Refresh the shared token and retry.
        if (!e.toString().contains('401')) rethrow;
        final refreshed = await auth.refreshSession();
        session = refreshed.session ?? auth.currentSession;
        if (session == null) rethrow;
        data = await _requestSharedNotes(session.accessToken);
      }
      final user = auth.currentUser;
      if (user == null || session == null) {
        throw Exception('Your ControlDeck session has expired. Return to ControlDeck and sign in again.');
      }
      client = Supabase.instance.client;
      token = session.accessToken;
      profile = Map<String, dynamic>.from(data['profile'] as Map);
      contactEmail.text = user.email ?? _notesAdminEmail;
      await loadLanguages();
      await loadProgress();
    } catch (e) {
      if (mounted) setState(() => error = friendly(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  @override void dispose() {
    for (final c in [email,password,name,search,contactName,contactEmail,contactSubject,contactMessage]) { c.dispose(); }
    super.dispose();
  }
  String friendly(Object e) => e.toString().replaceFirst('Exception: ', '');
  void applySession(String t, Map<String,dynamic> p) {
    token=t; profile=p;
    client=SupabaseClient(notesWorkspaceUrl,notesWorkspaceKey,headers:{'Authorization':'Bearer $t'},
      authOptions: const AuthClientOptions(autoRefreshToken:false));
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
  Future<void> tokenAction() async {
    String action = 'verify_email';
    final verificationToken = TextEditingController();
    final newPassword = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: const Text('Verify email or reset password'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: action, decoration: const InputDecoration(labelText: 'Action'),
          items: const [DropdownMenuItem(value: 'verify_email', child: Text('Verify email')), DropdownMenuItem(value: 'reset_password', child: Text('Reset password'))],
          onChanged: (v) => setDialog(() => action = v ?? action)),
        TextField(controller: verificationToken, decoration: const InputDecoration(labelText: 'Token from email')),
        if (action == 'reset_password') TextField(controller: newPassword, obscureText: true, decoration: const InputDecoration(labelText: 'New password (8+ characters)')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue'))],
    )));
    if (ok == true) {
      try {
        if (action == 'reset_password' && newPassword.text.length < 8) throw Exception('New password must be at least 8 characters.');
        await authCall(action, {'token': verificationToken.text.trim(), if (action == 'reset_password') 'newPassword': newPassword.text});
        if (mounted) setState(() => notice = action == 'verify_email' ? 'Email verified. You can sign in now.' : 'Password reset successfully. You can sign in with the new password.');
      } catch (e) { if (mounted) setState(() => error = friendly(e)); }
    }
    verificationToken.dispose(); newPassword.dispose();
  }
  Future<void> resendVerification() async {
    if (email.text.trim().isEmpty) { setState(() => error = 'Enter your email first.'); return; }
    try {
      await authCall('resend_verification', {'email': email.text.trim().toLowerCase()});
      if (mounted) setState(() => notice = 'If the account needs verification, a new email has been requested.');
    } catch (e) { if (mounted) setState(() => error = friendly(e)); }
  }

  Future<void> signOut() async {
    if (notesWorkspaceUrl == controlDeckWorkspaceUrl && controlDeckWorkspaceUrl.isNotEmpty && controlDeckWorkspaceKey.isNotEmpty && Supabase.instance.client.auth.currentUser != null) {
      Navigator.of(context).maybePop();
      return;
    }
    await storage.delete(key:_notesSessionKey);
    if(mounted)setState(()=>{token=null,profile=null,client=publicClient,language=null,topic=null,blocks=[],progress=[],page='Dashboard',notice='Signed out of Notes.'});
  }
  Future<void> loadLanguages() async {
    if(client==null)return;
    setState(()=>{loading=true,error=null});
    try {
      final rows = await client!.schema('notes').from('languages').select('*').order('sort_order').order('name');
      final topicRows = await client!.schema('notes').from('topics').select('*').order('sort_order').order('title');
      if (mounted) {
        languages = List<Map<String,dynamic>>.from(rows);
        allTopics = List<Map<String,dynamic>>.from(topicRows);
      }
    } catch(e) { if(mounted)setState(()=>error=friendly(e)); }
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
    try {
      final row = await client!.schema('notes').from('topic_content').select('content').eq('topic_id',item['id']).maybeSingle();
      final rawContent = row?['content'];
      final decodedContent = rawContent is String ? jsonDecode(rawContent) : rawContent;
      if (mounted) setState(() {
        blocks = decodedContent is List ? List<dynamic>.from(decodedContent) : <dynamic>[];
        page = 'Lesson';
      });
    } catch(e) { if(mounted)setState(()=>error=friendly(e)); }
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
  Future<void> loadActivity() async {
    if (!isAdmin) return;
    setState(() => {loading=true,error=null,page='Activity'});
    try { final rows=await client!.schema('notes').from('currently_online').select('*').order('last_seen_at',ascending:false).limit(100); if(mounted)onlineUsers=List<Map<String,dynamic>>.from(rows); } catch (_) { onlineUsers=[]; }
    try { final rows=await client!.schema('notes').from('login_activity').select('*').order('login_time',ascending:false).limit(100); if(mounted)loginActivity=List<Map<String,dynamic>>.from(rows); } catch (_) { loginActivity=[]; }
    try { final rows=await client!.schema('notes').from('page_visits').select('*').order('visit_time',ascending:false).limit(100); if(mounted)pageVisits=List<Map<String,dynamic>>.from(rows); } catch (_) { pageVisits=[]; }
    if(mounted)setState(()=>loading=false);
  }
  Future<void> copyActivity() async {
    final rows=activityTab=='Online'?onlineUsers:activityTab=='Logins'?loginActivity:pageVisits;
    final keys=rows.isEmpty?<String>[]:rows.first.keys.toList();
    final csv=[keys.join(','),...rows.map((r)=>keys.map((k)=>'"${(r[k]??'').toString().replaceAll('"','""')}"').join(','))].join('\n');
    await Clipboard.setData(ClipboardData(text:csv));
    if(mounted)setState(()=>notice='${rows.length} rows copied as CSV text.');
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
  int get _selectedNavIndex => switch (page) {
    'Home' => 0,
    'Dashboard' || 'Lessons' || 'Lesson' => 1,
    'Progress' => 2,
    'Profile' => 3,
    _ => 0,
  };

  void _selectNav(int index) {
    setState(() {
      error = null;
      notice = null;
      switch (index) {
        case 0:
          language = null; topic = null; blocks = []; page = 'Home';
          break;
        case 1:
          topic = null; blocks = [];
          page = language == null ? 'Dashboard' : 'Lessons';
          break;
        case 2:
          page = 'Progress';
          break;
        case 3:
          page = 'Profile';
          break;
      }
    });
  }

  @override Widget build(BuildContext context) {
    final ready=publicClient!=null; final theme=Theme.of(context);
    return Scaffold(appBar:AppBar(
      leading: IconButton(
        onPressed: () {
          if (topic != null) setState(() { topic = null; blocks = []; page = 'Lessons'; });
          else if (language != null) setState(() { language = null; page = 'Dashboard'; });
          else Navigator.of(context).maybePop();
        },
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Notes'),
      actions: [
        if (profile != null) PopupMenuButton<String>(
          tooltip: 'More Notes sections',
          onSelected: (value) {
            if (value == 'about') setState(() => page = 'About');
            if (value == 'contact') setState(() => page = 'Contact');
            if (value == 'admin') loadAdmin();
            if (value == 'activity') loadActivity();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'about', child: Text('About Notes')),
            const PopupMenuItem(value: 'contact', child: Text('Contact')),
            if (isAdmin) const PopupMenuItem(value: 'admin', child: Text('Admin management')),
            if (isAdmin) const PopupMenuItem(value: 'activity', child: Text('Activity monitor')),
          ],
        ),
        if (profile != null) IconButton(tooltip: 'Profile', onPressed: () => setState(() => page = 'Profile'), icon: const Icon(Icons.account_circle_outlined)),
        if (profile != null) IconButton(tooltip: usesSharedControlDeckAuth ? 'Back to ControlDeck' : 'Sign out', onPressed: signOut, icon: Icon(usesSharedControlDeckAuth ? Icons.arrow_back_rounded : Icons.logout_rounded)),
        const SizedBox(width: 8),
      ],
    ),
      body: !ready
          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Configure NOTES_SUPABASE_URL and NOTES_SUPABASE_ANON_KEY to connect your Notes Supabase project.')))
          : profile == null && !usesSharedControlDeckAuth
              ? authView(theme)
              : loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(padding: const EdgeInsets.all(18), children: [
                      if (error != null) message(error!, true),
                      if (profile == null && usesSharedControlDeckAuth)
                        Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
                          onPressed: initializeSharedNotes,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry shared session'),
                        )),
                      if (notice != null) message(notice!, false),
                      if (page == 'Home') ...homeView(theme),
                      if (page == 'Dashboard') ...dashboard(theme),
                      if (page == 'Lessons') ...lessonList(theme),
                      if (page == 'Lesson') ...lessonView(theme),
                      if (page == 'Progress') ...progressView(theme),
                      if (page == 'About') ...aboutView(),
                      if (page == 'Contact') ...contactView(),
                      if (page == 'Profile') ...profileView(theme),
                      if (page == 'Admin') ...adminView(theme),
                      if (page == 'Activity') ...activityView(theme),
                    ]),
      bottomNavigationBar: profile == null ? null : NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: _selectNav,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), selectedIcon: Icon(Icons.home_filled), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_rounded), label: 'Learn'),
          NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.account_circle_outlined), label: 'Profile'),
        ],
      ),
    );
  }
  Widget authView(ThemeData theme)=>Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:470),child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(22),children:[
    const _NotesHero(title:'Coding Notes',subtitle:'Programming lessons, learning progress and resources in one place.'),
    if(signUpMode)TextField(controller:name,decoration:const InputDecoration(labelText:'Full name')),
    const SizedBox(height:12),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email')),
    const SizedBox(height:10),TextField(controller:password,obscureText:true,onSubmitted:(_)=>submitAuth(),decoration:InputDecoration(labelText:'Password',helperText:signUpMode?'At least 8 characters':null)),
    if(error!=null)message(error!,true),if(notice!=null)message(notice!,false),
    const SizedBox(height:14),FilledButton(onPressed:busy?null:submitAuth,child:busy?const CircularProgressIndicator():Text(signUpMode?'Create Notes account':'Sign in')),
    if(!signUpMode)TextButton(onPressed:forgotPassword,child:const Text('Forgot password?')),
    if(!signUpMode)TextButton(onPressed:tokenAction,child:const Text('Enter verification/reset token')),
    if(!signUpMode)TextButton(onPressed:resendVerification,child:const Text('Resend verification email')),
    TextButton(onPressed:()=>setState(()=>{signUpMode=!signUpMode,error=null,notice=null}),child:Text(signUpMode?'Already registered? Sign in':'Create account')),
  ])));
  List<Widget> homeView(ThemeData theme) => [
    const _NotesHero(title: 'Welcome to Notes', subtitle: 'Your coding curriculum, lessons and learning progress in one place.'),
    LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 700 ? 3 : 1;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: columns == 1 ? 3.4 : 1.6,
        children: [
          _NotesStatCard(label: 'Languages', value: languages.length.toString(), icon: Icons.code_rounded),
          _NotesStatCard(label: 'Topics', value: allTopics.length.toString(), icon: Icons.menu_book_rounded),
          _NotesStatCard(label: 'Completed', value: progress.where((p) => p['completed'] == true).length.toString(), icon: Icons.check_circle_outline_rounded),
        ],
      );
    }),
    const SizedBox(height: 14),
    FilledButton.icon(onPressed: () => _selectNav(1), icon: const Icon(Icons.school_rounded), label: const Text('Browse all programming languages')),
    OutlinedButton.icon(onPressed: () => setState(() => page = 'Progress'), icon: const Icon(Icons.insights_rounded), label: const Text('View learning progress')),
    OutlinedButton.icon(onPressed: () => setState(() => page = 'Contact'), icon: const Icon(Icons.mail_outline_rounded), label: const Text('Contact Notes')),
  ];

  List<Widget> progressView(ThemeData theme) {
    final doneIds = progress.where((p) => p['completed'] == true).map((p) => p['topic_id'].toString()).toSet();
    final doneTopics = allTopics.where((t) => doneIds.contains(t['id'].toString())).toList();
    final total = allTopics.length;
    final count = doneTopics.length;
    final percent = total == 0 ? 0.0 : count / total;
    return [
      const _NotesHero(title: 'Learning progress', subtitle: 'Your completed lessons sync to your Notes account.'),
      Card(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$count of $total lessons completed', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: percent, minHeight: 8),
          const SizedBox(height: 8),
          Text((percent * 100).round().toString() + '% complete'),
        ]),
      )),
      const SizedBox(height: 12),
      if (doneTopics.isEmpty)
        const _NotesNotice(title: 'No completed lessons yet', detail: 'Open a topic and choose Mark complete to start tracking your progress.')
      else
        for (final t in doneTopics)
          Card(child: ListTile(
            leading: const Icon(Icons.check_circle_rounded, color: Colors.green),
            title: Text(t['title'].toString()),
            subtitle: Text(languages.firstWhere((l) => l['id'].toString() == t['language_id'].toString(), orElse: () => <String,dynamic>{'name':'Language'})['name'].toString()),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final lang = languages.where((l) => l['id'].toString() == t['language_id'].toString()).toList();
              if (lang.isNotEmpty) {
                await loadTopics(lang.first);
                await loadLesson(t);
              }
            },
          )),
    ];
  }

  List<Widget> dashboard(ThemeData theme){
    final q=query.toLowerCase();final visible=languages.where((l)=>q.isEmpty||[l['name'],l['description'],l['slug']].any((v)=>(v??'').toString().toLowerCase().contains(q))).toList();
    return [const _NotesHero(title:'Coding Notes',subtitle:'Database-driven coding notes for BCA/MCA students.'),
      Row(children:[Expanded(child:Text('${languages.length} languages',style:theme.textTheme.titleMedium)),Text('${progress.where((p)=>p['completed']==true).length} completed')]),
      TextField(controller:search,onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(labelText:'Search languages',prefixIcon:Icon(Icons.search_rounded))),
      Wrap(spacing:8,children:[
        ActionChip(label:const Text('About'),onPressed:()=>setState(()=>page='About')),
        ActionChip(label:const Text('Contact'),onPressed:()=>setState(()=>page='Contact')),
        if(isAdmin)ActionChip(label:const Text('Admin management'),onPressed:loadAdmin),
        if(isAdmin)ActionChip(label:const Text('Activity monitor'),onPressed:loadActivity),
      ]),
      LayoutBuilder(builder:(context,box){
        final cols=box.maxWidth>760?3:box.maxWidth>460?2:1;
        return GridView.count(
          shrinkWrap:true,
          physics:const NeverScrollableScrollPhysics(),
          crossAxisCount:cols,
          mainAxisSpacing:12,
          crossAxisSpacing:12,
          // Give the icon and language title enough vertical room on phones and tablets.
          childAspectRatio:cols==1?2.7:cols==2?1.22:1.0,
          children:visible.map((l)=>Card(
            clipBehavior:Clip.antiAlias,
            child:InkWell(
              onTap:()=>loadTopics(l),
              child:Padding(
                padding:const EdgeInsets.all(16),
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  mainAxisAlignment:MainAxisAlignment.start,
                  children:[
                    Row(children:[
                      _NotesLanguageIcon(language:l,size:42),
                      const Spacer(),
                      Icon(Icons.arrow_outward_rounded,color:theme.colorScheme.onSurfaceVariant,size:19),
                    ]),
                    const SizedBox(height:12),
                    Text(l['name']?.toString()??'Programming',maxLines:1,overflow:TextOverflow.ellipsis,style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
                    const SizedBox(height:4),
                    Expanded(child:Text(l['description']?.toString().trim().isNotEmpty==true?l['description'].toString():'Explore lessons, examples and practice notes.',maxLines:3,overflow:TextOverflow.ellipsis,style:theme.textTheme.bodySmall)),
                    const SizedBox(height:6),
                    Text('Explore lessons  →',style:theme.textTheme.labelLarge?.copyWith(color:theme.colorScheme.primary,fontWeight:FontWeight.w700)),
                  ],
                ),
              ),
            ),
          )).toList(),
        );
      })];
  }
  List<Widget> lessonList(ThemeData theme)=>[
    _NotesHero(title:language?['name']?.toString()??'Lessons',subtitle:language?['description']?.toString()??'Select a lesson.'),
    Row(children:[Expanded(child:Text('${topics.length} lessons')),if(isAdmin)FilledButton.tonalIcon(onPressed:()=>editTopic(),icon:const Icon(Icons.add),label:const Text('Add topic'))]),
    for(final t in topics)Card(child:ListTile(leading:Icon(completed(t['id'].toString())?Icons.check_circle:Icons.menu_book_rounded),title:Text(t['title'].toString()),subtitle:Text(completed(t['id'].toString())?'Completed':'Lesson'),trailing:Wrap(children:[
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
  List<Widget> profileView(ThemeData theme)=>[const _NotesHero(title:'My Notes profile',subtitle:'Account and learning progress.'),Card(child:ListTile(leading:const Icon(Icons.account_circle),title:Text(profile?['full_name']?.toString()??profile?['name']?.toString()??'Notes user'),subtitle:Text(profile?['email']?.toString()??''))),Text('${progress.where((p)=>p['completed']==true).length} lessons completed'),FilledButton.tonalIcon(onPressed:changePassword,icon:const Icon(Icons.password),label:const Text('Change password')),if(notesWorkspaceUrl != controlDeckWorkspaceUrl)OutlinedButton.icon(onPressed:signOut,icon:const Icon(Icons.logout),label:const Text('Sign out')) else const _NotesNotice(title:'Shared ControlDeck sign-in',detail:'This Notes workspace uses your existing ControlDeck session. Sign out from the main ControlDeck account menu to end the shared session.')];
  Future<void> changePassword() async {
    final current=TextEditingController(),next=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Change password'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:current,obscureText:true,decoration:const InputDecoration(labelText:'Current password')),TextField(controller:next,obscureText:true,decoration:const InputDecoration(labelText:'New password'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Update'))]));
    if(ok==true)try{
      if(notesWorkspaceUrl == controlDeckWorkspaceUrl && Supabase.instance.client.auth.currentUser != null) {
        final auth = Supabase.instance.client.auth;
        await auth.signInWithPassword(email: auth.currentUser!.email!, password: current.text);
        await auth.updateUser(UserAttributes(password: next.text));
      } else {
        await authCall('change_password',{'currentPassword':current.text,'newPassword':next.text});
      }
      if(mounted)setState(()=>notice='Password updated.');
    }catch(e){if(mounted)setState(()=>error=friendly(e));}
    current.dispose();next.dispose();
  }
  List<Widget> activityView(ThemeData theme) {
    final rows=activityTab=='Online'?onlineUsers:activityTab=='Logins'?loginActivity:pageVisits;
    return [
      const _NotesHero(title:'Notes activity',subtitle:'Review currently online users, recent sign-ins and page visits.'),
      Wrap(spacing:8,children:[
        ChoiceChip(label:Text('Online (${onlineUsers.length})'),selected:activityTab=='Online',onSelected:(_){setState(()=>activityTab='Online');}),
        ChoiceChip(label:Text('Logins (${loginActivity.length})'),selected:activityTab=='Logins',onSelected:(_){setState(()=>activityTab='Logins');}),
        ChoiceChip(label:Text('Page visits (${pageVisits.length})'),selected:activityTab=='Visits',onSelected:(_){setState(()=>activityTab='Visits');}),
        OutlinedButton.icon(onPressed:copyActivity,icon:const Icon(Icons.copy_rounded),label:const Text('Copy CSV')),
        OutlinedButton.icon(onPressed:loadActivity,icon:const Icon(Icons.refresh_rounded),label:const Text('Refresh')),
      ]),
      const SizedBox(height:10),
      if(rows.isEmpty)const _NotesNotice(title:'No activity rows available',detail:'The source Notes activity tables may not be installed or may not allow this admin token to read them.'),
      for(final row in rows)Card(child:ListTile(title:Text((row['username']??row['email']??row['page_name']??row['page_url']??row['user_id']??'Activity record').toString()),subtitle:Text(row.entries.where((e)=>e.value!=null).take(5).map((e)=>'${e.key}: ${e.value}').join(' · ')))),
    ];
  }
  List<Widget> adminView(ThemeData theme)=>[
    _NotesHero(title:'Notes Admin Management',subtitle:'Manage curriculum, lesson content and profiles.'),
    Align(alignment:Alignment.centerLeft,child:OutlinedButton.icon(onPressed:loadActivity,icon:const Icon(Icons.query_stats_rounded),label:const Text('Open activity monitor'))),
    Row(children:[Expanded(child:Text('Languages',style:theme.textTheme.titleLarge)),FilledButton.icon(onPressed:()=>editLanguage(),icon:const Icon(Icons.add),label:const Text('Add'))]),
    for(final l in languages)Card(child:ListTile(title:Text(l['name'].toString()),subtitle:Text('${l['slug']} · order ${l['sort_order']}'),trailing:Wrap(children:[IconButton(onPressed:()=>editLanguage(l),icon:const Icon(Icons.edit_outlined)),IconButton(onPressed:()=>deleteRow('languages',l),icon:const Icon(Icons.delete_outline))]))),
    Row(children:[Expanded(child:Text('Topics',style:theme.textTheme.titleLarge)),FilledButton.icon(onPressed:()=>editTopic(),icon:const Icon(Icons.add),label:const Text('Add'))]),
    for(final t in topics)Card(child:ListTile(title:Text(t['title'].toString()),trailing:Wrap(children:[IconButton(onPressed:()=>editTopic(t),icon:const Icon(Icons.edit_outlined)),IconButton(onPressed:()=>editContent(t),icon:const Icon(Icons.edit_note)),IconButton(onPressed:()=>deleteRow('topics',t),icon:const Icon(Icons.delete_outline))]))),
    Text('Profiles',style:theme.textTheme.titleLarge),for(final p in profiles)Card(child:ListTile(title:Text(p['full_name']?.toString()??'Unnamed user'),subtitle:Text(p['email']?.toString()??''))),
    const _NotesNotice(title:'Database policy required',detail:'Admin writes are enforced by Supabase RLS. Apply docs/NOTES_ADMIN_POLICIES.sql in the Notes project before using admin edit controls.'),
  ];
  Widget message(String text,bool isError)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:(isError?Theme.of(context).colorScheme.error:Colors.green).withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),child:Text(text,style:TextStyle(color:isError?Theme.of(context).colorScheme.error:Colors.green)));
}

class _NotesStatCard extends StatelessWidget {
  const _NotesStatCard({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      ])),
    ]),
  ));
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
    if (type == 'list') {
      final items = List<dynamic>.from(block['items'] as List? ?? const []);
      final ordered = block['ordered'] == true;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          ordered ? '${i + 1}.' : '•',
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(items[i] is Map ? (items[i]['text'] ?? '').toString() : items[i].toString()),
                            if (items[i] is Map && items[i]['children'] is List)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final child in List<dynamic>.from(items[i]['children'] as List))
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('–  '),
                                            Expanded(child: Text(child.toString())),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if(type=='image'){final src=(block['src']??'').toString();if(src.isEmpty)return const SizedBox.shrink();return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Image.network(src,fit:BoxFit.contain,semanticLabel:(block['alt']??'Lesson image').toString(),errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined)),if((block['caption']??'').toString().isNotEmpty)Text(block['caption'].toString())])));}
    if(type=='table'){final headers=List<dynamic>.from(block['headers'] as List? ?? const []);final rows=List<dynamic>.from(block['rows'] as List? ?? const []);if(headers.isEmpty)return const SizedBox.shrink();return Card(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:headers.map((h)=>DataColumn(label:Text(h.toString()))).toList(),rows:rows.map((r){final cells=List<dynamic>.from(r as List);return DataRow(cells:List.generate(headers.length,(i)=>DataCell(Text(i<cells.length?cells[i].toString():''))));}).toList())));}
    if(type=='divider')return const Divider(height:28);
    if(type=='note'){final v=(block['variant']??'info').toString();final color=v=='warning'?Colors.orange:v=='tip'?Colors.green:Colors.amber;return Card(color:color.withValues(alpha:.12),child:Padding(padding:const EdgeInsets.all(14),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(v=='warning'?Icons.warning_amber_rounded:v=='tip'?Icons.lightbulb_outline_rounded:Icons.info_outline_rounded,color:color),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[if((block['title']??'').toString().isNotEmpty)Text(block['title'].toString(),style:const TextStyle(fontWeight:FontWeight.w800)),Text(text)]))])));}
    return Padding(padding:const EdgeInsets.symmetric(vertical:7),child:SelectableText(text,style:theme.textTheme.bodyLarge?.copyWith(height:1.55)));
  }
}


class _NotesLanguageIcon extends StatelessWidget {
  const _NotesLanguageIcon({required this.language, this.size = 36});
  final Map<String, dynamic> language;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = (language['name'] ?? '').toString().trim().toLowerCase();
    final slug = (language['slug'] ?? '').toString().trim().toLowerCase();
    final key = '$name $slug';
    FaIconData? icon;
    String? mark;
    Color color = const Color(0xFF64748B);

    if (key.contains('c++') || key.contains('cpp')) {
      mark = 'C++'; color = const Color(0xFF00599C);
    } else if (name == 'c' || slug == 'c' || name.startsWith('c language')) {
      mark = 'C'; color = const Color(0xFF283593);
    } else if (key.contains('javascript') || slug == 'js' || name == 'js') {
      icon = FontAwesomeIcons.js; color = const Color(0xFFF0DB4F);
    } else if (key.contains('html')) {
      icon = FontAwesomeIcons.html5; color = const Color(0xFFE34F26);
    } else if (key.contains('css')) {
      icon = FontAwesomeIcons.css3Alt; color = const Color(0xFF1572B6);
    } else if (key.contains('bootstrap')) {
      icon = FontAwesomeIcons.bootstrap; color = const Color(0xFF7952B3);
    } else if (key.contains('php')) {
      icon = FontAwesomeIcons.php; color = const Color(0xFF777BB4);
    } else if (key.contains('java')) {
      icon = FontAwesomeIcons.java; color = const Color(0xFFED8B00);
    } else if (key.contains('python')) {
      icon = FontAwesomeIcons.python; color = const Color(0xFF3776AB);
    } else if (key.contains('react')) {
      icon = FontAwesomeIcons.react; color = const Color(0xFF149ECA);
    } else if (key.contains('node')) {
      icon = FontAwesomeIcons.nodeJs; color = const Color(0xFF339933);
    } else if (key.contains('postgres') || key.contains('mysql') || key.contains('sql') || key.contains('database')) {
      icon = FontAwesomeIcons.database; color = const Color(0xFF4479A1);
    } else if (key.contains('git')) {
      icon = FontAwesomeIcons.gitAlt; color = const Color(0xFFF05032);
    } else if (key.contains('flutter')) {
      mark = 'Fl'; color = const Color(0xFF02569B);
    } else if (key.contains('dart')) {
      mark = 'D'; color = const Color(0xFF02569B);
    } else if (key.contains('c#') || key.contains('csharp')) {
      mark = 'C#'; color = const Color(0xFF68217A);
    } else if (key.contains('typescript')) {
      mark = 'TS'; color = const Color(0xFF3178C6);
    } else {
      icon = FontAwesomeIcons.code;
    }

    return Container(
      width: size + 22,
      height: size + 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.35), width: 1.2),
      ),
      child: mark != null
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(mark, maxLines: 1, style: TextStyle(
                color: color,
                fontSize: mark.length >= 4 ? size * 0.30 : size * 0.46,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              )),
            )
          : FaIcon(icon ?? FontAwesomeIcons.code, size: size, color: color),
    );
  }
}
