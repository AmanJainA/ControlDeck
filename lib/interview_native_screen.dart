import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class InterviewNativeScreenV2 extends StatefulWidget {
  const InterviewNativeScreenV2({super.key});
  @override State<InterviewNativeScreenV2> createState()=>_InterviewNativeScreenV2State();
}
class _InterviewNativeScreenV2State extends State<InterviewNativeScreenV2>{
  late final SupabaseClient db;
  bool loading=true,busy=false,submitting=false;
  String? error;
  Map<String,dynamic>? profile,company,attempt;
  List<Map<String,dynamic>> questions=[],attempts=[],users=[],activity=[];
  final Map<String,String> answers={};
  String page='Dashboard';
  int seconds=0;
  Timer? timer;
  bool get admin=>(profile?['usertype']??'').toString()=='admin';
  String get who=>(profile?['name']??'there').toString();
  double n(dynamic x)=>x is num?x.toDouble():double.tryParse('$x')??0;
  String clean(Object e)=>e.toString().replaceFirst('Exception: ','');
  @override void initState(){super.initState();db=SupabaseClient(SupabaseConfig.primaryUrl,SupabaseConfig.primaryKey);restore();}
  @override void dispose(){timer?.cancel();db.dispose();super.dispose();}
  void note(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  Future<void> restore()async{
    setState(()=>loading=true);error=null;
    try{
      final auth=Supabase.instance.client;
      var session=auth.auth.currentSession;
      if(session==null){await auth.auth.refreshSession();session=auth.auth.currentSession;}
      if(session==null)throw Exception('No ControlDeck session. Sign in to ControlDeck once, then reopen Interview.');
      final res=await auth.functions.invoke('controldeck-sso',headers:{'Authorization':'Bearer '+session.accessToken},body:{'app':'interview','action':'exchange'});
      final b=res.data is Map?Map<String,dynamic>.from(res.data as Map):<String,dynamic>{};
      if(res.status>=400||b['ok']!=true||b['profile'] is! Map)throw Exception((b['error']??'Could not verify your ControlDeck session.').toString());
      profile=Map<String,dynamic>.from(b['profile'] as Map);
      if(!mounted)return;setState(()=>loading=false);await refreshData();
    }catch(e){if(mounted)setState(() { loading = false; error = clean(e); });}
  }
  Future<void> refreshData()async{
    if(profile==null)return;setState(()=>busy=true);error=null;
    try{
      final s=db.schema('interview');
      final c=await s.from('company_info').select('id,about,instructions,duration_minutes').eq('id',1).maybeSingle();
      final q=await s.from('questions').select('id,assessment_type,question_text,option_a,option_b,option_c,option_d,correct_option,marks,sort_order').eq('assessment_type','general').order('sort_order');
      final a=await s.from('assessment_attempts').select('*').eq('user_id',profile!['id']).eq('assessment_type','general').order('started_at',ascending:false).limit(10);
      if(!mounted)return;setState(() { company = c == null ? null : Map<String,dynamic>.from(c); questions = List<Map<String,dynamic>>.from(q); attempts = List<Map<String,dynamic>>.from(a); });
      final active=attempts.where((x)=>x['status']=='in_progress').firstOrNull;if(active!=null)await resume(active);
      if(admin){await loadAdmin();await loadUsers();}
    }catch(e){if(mounted)setState(()=>error='Interview data could not load: '+clean(e));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> loadAdmin()async{final a=await db.schema('interview').from('assessment_attempts').select('*').order('submitted_at',ascending:false).limit(1000);if(mounted)setState(()=>attempts=List<Map<String,dynamic>>.from(a));}
  Future<void> resume(Map<String,dynamic> a)async{
    final rows=await db.schema('interview').from('user_answers').select('question_id,selected_option').eq('attempt_id',a['id']);
    answers..clear()..addEntries(List<Map<String,dynamic>>.from(rows).where((x)=>x['selected_option']!=null).map((x)=>MapEntry(x['question_id'].toString(),x['selected_option'].toString())));
    attempt=a;final start=DateTime.tryParse(a['started_at']?.toString()??'')?.toLocal();final mins=(a['duration_minutes'] as num?)?.toInt()??(company?['duration_minutes'] as num?)?.toInt()??30;
    seconds=(mins*60-(start==null?0:DateTime.now().difference(start).inSeconds)).clamp(0,mins*60);
    if(seconds<=0){await submit(auto:true);return;}
    timer?.cancel();timer=Timer.periodic(const Duration(seconds:1),(t){if(!mounted||attempt==null||attempt!['status']!='in_progress'){t.cancel();return;}if(seconds<=1){setState(()=>seconds=0);t.cancel();submit(auto:true);}else setState(()=>seconds--);});
  }
  Future<void> startAssessment()async{
    if(questions.isEmpty){note('No general assessment questions are configured.');return;}setState(()=>busy=true);
    try{
      final s=db.schema('interview');final done=await s.from('assessment_attempts').select('id').eq('user_id',profile!['id']).eq('assessment_type','general').eq('status','submitted').limit(1);
      if((done as List).isNotEmpty){note('Assessment already submitted. Retakes are disabled.');await refreshData();return;}
      final old=await s.from('assessment_attempts').select('*').eq('user_id',profile!['id']).eq('assessment_type','general').eq('status','in_progress').maybeSingle();
      if(old!=null)await resume(Map<String,dynamic>.from(old));else{final duration=(company?['duration_minutes'] as num?)?.toInt()??30;final max=questions.fold<double>(0,(sum,q)=>sum+n(q['marks']));final a=await s.from('assessment_attempts').insert({'user_id':profile!['id'],'assessment_type':'general','total_questions':questions.length,'max_score':max,'duration_minutes':duration>0?duration:30}).select().single();await resume(Map<String,dynamic>.from(a));}
      if(mounted)setState(()=>page='Assessment');
    }catch(e){if(mounted)setState(()=>error=clean(e));}finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> save(Map<String,dynamic> q,String option)async{
    if(attempt==null||busy||attempt!['status']!='in_progress')return;setState(() { answers[q['id'].toString()] = option; busy = true; });
    try{await db.schema('interview').from('user_answers').upsert({'attempt_id':attempt!['id'],'question_id':q['id'],'selected_option':option,'is_correct':q['correct_option']==option},onConflict:'attempt_id,question_id');}
    catch(e){if(mounted)setState(()=>error='Answer save failed: '+clean(e));}finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> submit({bool auto=false})async{
    if(attempt==null||attempt!['status']=='submitted'||submitting)return;submitting=true;timer?.cancel();setState(()=>busy=true);
    try{
      final rows=await db.schema('interview').from('user_answers').select('question_id,is_correct').eq('attempt_id',attempt!['id']);final list=List<Map<String,dynamic>>.from(rows);
      final correct=list.where((x)=>x['is_correct']==true).length;
      final score=list.where((x)=>x['is_correct']==true).fold<double>(0,(sum,a){final q=questions.where((q)=>q['id'].toString()==a['question_id'].toString()).firstOrNull;return sum+(q==null?0:n(q['marks']));});
      final max=questions.fold<double>(0,(sum,q)=>sum+n(q['marks']));
      await db.schema('interview').from('assessment_attempts').update({'status':'submitted','submitted_at':DateTime.now().toUtc().toIso8601String(),'correct_count':correct,'score':score,'max_score':max,'total_questions':questions.length,'percentage':max<=0?0:double.parse((score/max*100).toStringAsFixed(2))}).eq('id',attempt!['id']).eq('user_id',profile!['id']).eq('status','in_progress');
      if(!mounted)return;setState(() { attempt = {...attempt!, 'status':'submitted', 'correct_count':correct, 'score':score, 'max_score':max, 'percentage':max<=0?0:score/max*100}; page = 'Result'; });note(auto?'Time ended; assessment submitted automatically.':'Assessment submitted.');await refreshData();if(mounted)setState(()=>page='Result');
    }catch(e){if(mounted)setState(()=>error='Submission failed: '+clean(e));}finally{submitting=false;if(mounted)setState(()=>busy=false);}
  }
  Future<void> open(String p)async{
    setState(() { page = p; error = null; });
    try{
      if(p=='Results'||(p=='Dashboard'&&admin)){await loadAdmin();final u=await db.schema('interview').from('users').select('id,name,email,stream,location,usertype,created_date').order('created_date',ascending:false);if(mounted)setState(()=>users=List<Map<String,dynamic>>.from(u));}
      if(p=='Questions'){final q=await db.schema('interview').from('questions').select('*').order('sort_order');if(mounted)setState(()=>questions=List<Map<String,dynamic>>.from(q));}
      if(p=='Tracking'){final a=await db.schema('interview').from('page_activity').select('*').order('visit_time',ascending:false).limit(1000);if(mounted)setState(()=>activity=List<Map<String,dynamic>>.from(a));}
      if(p=='Users'){final u=await db.schema('interview').from('users').select('id,name,email,stream,location,usertype,created_date').order('created_date',ascending:false);if(mounted)setState(()=>users=List<Map<String,dynamic>>.from(u));}
    }catch(e){if(mounted)setState(()=>error=clean(e));}
  }
  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(appBar:AppBar(title:Text('Interview')),body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[CircularProgressIndicator(),SizedBox(height:12),Text('Opening Interview with your ControlDeck session…')])));
    if(profile==null)return Scaffold(appBar:AppBar(title:const Text('Interview')),body:Center(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Interview could not connect to the existing session'),Text(error??'ControlDeck session unavailable'),FilledButton(onPressed:restore,child:const Text('Check session again')),TextButton(onPressed:()=>Navigator.of(context).maybePop(),child:const Text('Back to ControlDeck'))]))));
    final nav=admin?const ['Dashboard','Assessment','Results','Users','Tracking','Questions','Content']:const ['Dashboard','Assessment','Result'];
    return Scaffold(appBar:AppBar(leading:IconButton(onPressed:()=>Navigator.of(context).maybePop(),icon:const Icon(Icons.arrow_back)),title:const Text('Interview'),actions:[if(busy)const Padding(padding:EdgeInsets.all(14),child:SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))),IconButton(onPressed:refreshData,icon:const Icon(Icons.refresh))]),body:Column(children:[
      ListTile(leading:const CircleAvatar(child:Icon(Icons.verified_user)),title:Text('Welcome, $who'),subtitle:Text((profile!['email']??'').toString()+' · '+(admin?'Administrator':'Candidate')),trailing:const Icon(Icons.cloud_done,color:Color(0xFF8FA600))),
      if(error!=null)Container(width:double.infinity,padding:const EdgeInsets.all(8),color:Theme.of(context).colorScheme.errorContainer,child:Text(error!)),
      if(page!='Assessment')SizedBox(height:50,child:ListView(scrollDirection:Axis.horizontal,children:[for(final p in nav)Padding(padding:const EdgeInsets.all(4),child:ChoiceChip(label:Text(p),selected:page==p,onSelected:(_)=>open(p)))])),
      Expanded(child:content()),
    ]));
  }
  Widget content(){if(page=='Assessment')return assessment();if(page=='Result')return result();if(page=='Results')return results();if(page=='Users')return usersPage();if(page=='Tracking')return trackingPage();if(page=='Questions')return questionsPage();if(page=='Content')return contentPage();return admin?adminHome():userHome();}
  Widget info(String title,String body,IconData icon)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:const Color(0xFF8FA600)),const SizedBox(width:8),Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17))]),const SizedBox(height:10),SelectableText(body,style:const TextStyle(height:1.5))])));
  Widget userHome()=>ListView(padding:const EdgeInsets.all(14),children:[info('About the company',company?['about']?.toString()??'No company information added.',Icons.business),info('Instructions',company?['instructions']?.toString()??'No instructions added.',Icons.rule),info('General assessment',questions.length.toString()+' questions · '+(company?['duration_minutes']??30).toString()+' minutes',Icons.quiz),FilledButton.icon(onPressed:busy?null:startAssessment,icon:const Icon(Icons.play_arrow),label:Text(attempt?['status']=='in_progress'?'Resume assessment':'Start assessment')),if(attempts.any((a)=>a['status']=='submitted'))const Text('Submitted assessment cannot be retaken.'),for(final a in attempts)ListTile(title:Text((a['assessment_type']??'general').toString()+' assessment'),subtitle:Text((a['status']??'').toString()+' · '+(a['started_at']??'').toString()),trailing:Text(a['status']=='submitted'?n(a['percentage']).toStringAsFixed(1)+'%':'Resume'))]);
  Widget assessment(){
    if(attempt==null||attempt!['status']=='submitted')return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.quiz,size:40),Text(attempt?['status']=='submitted'?'Assessment submitted':'Ready to begin'),FilledButton(onPressed:attempt?['status']=='submitted'?null:startAssessment,child:const Text('Start assessment'))]));
    return Column(children:[Container(width:double.infinity,padding:const EdgeInsets.all(12),color:Theme.of(context).colorScheme.surfaceContainerLow,child:Row(children:[Expanded(child:Text('Answered '+answers.length.toString()+'/'+questions.length.toString())),Text((seconds~/60).toString().padLeft(2,'0')+':'+(seconds%60).toString().padLeft(2,'0'),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900))])),Expanded(child:ListView(padding:const EdgeInsets.all(12),children:[for(var i=0;i<questions.length;i++)question(i,questions[i]),FilledButton.icon(onPressed:busy?null:()async{if(await confirm('Submit assessment?','You cannot retake it after submission.')==true)await submit();},icon:const Icon(Icons.send),label:const Text('Submit assessment'))]))]);
  }
  Widget question(int i,Map<String,dynamic> q){final id=q['id'].toString();final opts={'A':q['option_a'],'B':q['option_b'],'C':q['option_c'],'D':q['option_d']};return Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Question '+(i+1).toString()+' · '+(q['marks']??1).toString()+' marks',style:const TextStyle(color:Color(0xFF8FA600),fontWeight:FontWeight.w800)),const SizedBox(height:8),Text((q['question_text']??'').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),for(final o in opts.entries)RadioListTile<String>(contentPadding:EdgeInsets.zero,dense:true,value:o.key,groupValue:answers[id],title:Text(o.key+'. '+(o.value??'').toString()),onChanged:busy?(v){}:(v){if(v!=null)save(q,v);})])));}
  Widget result(){final a=attempts.where((x)=>x['status']=='submitted').firstOrNull??attempt;if(a==null||a['status']!='submitted')return ListView(padding:const EdgeInsets.all(16),children:[info('Your result','Submit the assessment to see your result.',Icons.emoji_events)]);return ListView(padding:const EdgeInsets.all(16),children:[info('Result',n(a['percentage']).toStringAsFixed(1)+'% · '+(a['correct_count']??0).toString()+' correct answers',Icons.emoji_events),info('Score',(a['score']??0).toString()+' / '+(a['max_score']??0).toString()+' · submitted',Icons.verified)]);}
  Widget adminHome(){final done=attempts.where((a)=>a['status']=='submitted').toList();final today=DateTime.now();final todayCount=users.where((u){final d=DateTime.tryParse(u['created_date']?.toString()??'');return d!=null&&d.year==today.year&&d.month==today.month&&d.day==today.day;}).length;final buckets=[('0–69%',done.where((a)=>n(a['percentage'])<70).length),('70–79%',done.where((a)=>n(a['percentage'])>=70&&n(a['percentage'])<80).length),('80–89%',done.where((a)=>n(a['percentage'])>=80&&n(a['percentage'])<90).length),('90–99%',done.where((a)=>n(a['percentage'])>=90&&n(a['percentage'])<100).length),('100%',done.where((a)=>n(a['percentage'])>=100).length)];return RefreshIndicator(onRefresh:()async{await loadAdmin();await open('Users');},child:ListView(padding:const EdgeInsets.all(14),children:[Text('Admin Dashboard',style:Theme.of(context).textTheme.headlineSmall),info('Total users',users.length.toString(),Icons.people),info('Attempted assessment',attempts.map((a)=>a['user_id']).toSet().length.toString(),Icons.assignment_turned_in),info('Registered today',todayCount.toString(),Icons.person_add),const Text('Score distribution'),for(final b in buckets)Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[SizedBox(width:75,child:Text(b.$1)),Expanded(child:LinearProgressIndicator(value:done.isEmpty?0:b.$2/done.length)),const SizedBox(width:8),Text(b.$2.toString())])),const Text('Recent submissions'),for(final a in done.take(10))ListTile(title:Text('User '+a['user_id'].toString()),subtitle:Text((a['correct_count']??0).toString()+'/'+(a['total_questions']??0).toString()+' correct'),trailing:Text(n(a['percentage']).toStringAsFixed(1)+'%'))]));}
  Widget results()=>ListView(padding:const EdgeInsets.all(12),children:[Text('Assessment Results',style:Theme.of(context).textTheme.titleLarge),if(attempts.isEmpty)const Text('No attempts found.'),for(final a in attempts)Card(child:ListTile(title:Text('User '+a['user_id'].toString()),subtitle:Text((a['status']??'').toString()+' · '+(a['correct_count']??0).toString()+'/'+(a['total_questions']??0).toString()+' · '+(a['submitted_at']??'Not submitted').toString()),trailing:Text(a['status']=='submitted'?n(a['percentage']).toStringAsFixed(1)+'%':'In progress')))]);
  Widget usersPage()=>ListView(padding:const EdgeInsets.all(12),children:[Row(children:[Expanded(child:Text('Manage users ('+users.length.toString()+')',style:Theme.of(context).textTheme.titleLarge)),IconButton(onPressed:()=>open('Users'),icon:const Icon(Icons.refresh)),FilledButton(onPressed:addUser,child:const Text('Add user'))]),for(final u in users)Card(child:ListTile(title:Text((u['name']??'').toString()),subtitle:Text((u['email']??'').toString()+' · '+(u['stream']??'').toString()+' · '+(u['usertype']??'user').toString()),trailing:PopupMenuButton<String>(onSelected:(v)=>v=='role'?changeRole(u):deleteUser(u),itemBuilder:(_)=>const[PopupMenuItem(value:'role',child:Text('Toggle role')),PopupMenuItem(value:'delete',child:Text('Delete user'))])))]);
  Future<void> addUser() async {
    final fields = <String,TextEditingController>{
      'name':TextEditingController(), 'email':TextEditingController(), 'password':TextEditingController(),
      'registration_no':TextEditingController(), 'contact_number':TextEditingController(),
      'gender':TextEditingController(), 'father_name':TextEditingController(),
      'stream':TextEditingController(), 'location':TextEditingController(),
    };
    final ok = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Add Interview user'),
      content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        for(final e in fields.entries) Padding(padding:const EdgeInsets.only(bottom:8),child:TextField(
          controller:e.value, obscureText:e.key=='password',
          keyboardType:e.key=='email'?TextInputType.emailAddress:e.key=='contact_number'?TextInputType.phone:TextInputType.text,
          decoration:InputDecoration(labelText:e.key.replaceAll('_',' ')),
        )),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Create user'))],
    ));
    try {
      if(ok==true) {
        if(fields['name']!.text.trim().isEmpty || fields['email']!.text.trim().isEmpty || fields['password']!.text.length<6) {
          throw Exception('Name, email and a password of at least 6 characters are required.');
        }
        final result=await db.schema('interview').rpc('register_user',params:{
          'p_name':fields['name']!.text.trim(),
          'p_email':fields['email']!.text.trim().toLowerCase(),
          'p_password':fields['password']!.text,
          'p_stream':fields['stream']!.text.trim().isEmpty?null:fields['stream']!.text.trim(),
          'p_location':fields['location']!.text.trim().isEmpty?null:fields['location']!.text.trim(),
          'p_registration_no':fields['registration_no']!.text.trim().isEmpty?null:fields['registration_no']!.text.trim(),
          'p_contact_number':fields['contact_number']!.text.trim().isEmpty?null:fields['contact_number']!.text.trim(),
          'p_gender':fields['gender']!.text.trim().isEmpty?null:fields['gender']!.text.trim(),
          'p_father_name':fields['father_name']!.text.trim().isEmpty?null:fields['father_name']!.text.trim(),
        });
        if(result is Map && result['error']!=null) throw Exception(result['error'].toString());
        await open('Users');
        note('Interview user created.');
      }
    } catch(e) { showError(clean(e)); }
    finally { for(final controller in fields.values) { controller.dispose(); } }
  }

  Future<void> changeRole(Map<String,dynamic> u)async{if(u['id'].toString()==profile?['id'].toString()){showError('Cannot change your own role.');return;}try{await db.schema('interview').from('users').update({'usertype':u['usertype']=='admin'?'user':'admin'}).eq('id',u['id']);await open('Users');}catch(e){showError(clean(e));}}
  Future<void> deleteUser(Map<String,dynamic> u)async{if(u['id'].toString()==profile?['id'].toString()){showError('Cannot delete your own account.');return;}if(await confirm('Delete user?','Delete '+(u['name']??'user').toString()+' and linked attempts?')!=true)return;try{await db.schema('interview').from('users').delete().eq('id',u['id']);await open('Users');}catch(e){showError(clean(e));}}
  Widget questionsPage()=>Column(children:[Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:Text('Questions ('+questions.length.toString()+')',style:Theme.of(context).textTheme.titleLarge)),FilledButton(onPressed:()=>editQuestion(),child:const Text('Add'))])),Expanded(child:ListView(children:[for(final q in questions)Card(child:ListTile(title:Text((q['question_text']??'').toString()),subtitle:Text((q['assessment_type']??'general').toString()+' · '+(q['marks']??1).toString()+' marks'),trailing:PopupMenuButton<String>(onSelected:(v)=>v=='edit'?editQuestion(q):deleteQuestion(q),itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'delete',child:Text('Delete'))])))]))]);
  Future<void> editQuestion([Map<String,dynamic>? q])async{
    final f=<String,TextEditingController>{'type':TextEditingController(text:q?['assessment_type']?.toString()??'general'),'question':TextEditingController(text:q?['question_text']?.toString()??''),'a':TextEditingController(text:q?['option_a']?.toString()??''),'b':TextEditingController(text:q?['option_b']?.toString()??''),'c':TextEditingController(text:q?['option_c']?.toString()??''),'d':TextEditingController(text:q?['option_d']?.toString()??''),'marks':TextEditingController(text:q?['marks']?.toString()??'1'),'order':TextEditingController(text:q?['sort_order']?.toString()??questions.length.toString())};String correct=q?['correct_option']?.toString()??'A';
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(title:Text(q==null?'Add question':'Edit question'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[for(final e in f.entries)Padding(padding:const EdgeInsets.only(bottom:8),child:TextField(controller:e.value,maxLines:e.key=='question'?3:1,decoration:InputDecoration(labelText:e.key.toUpperCase()))),DropdownButtonFormField<String>(value:correct,items:const['A','B','C','D'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setLocal(()=>correct=v??correct),decoration:const InputDecoration(labelText:'Correct option'))]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))])));
    try{if(ok==true){final d=<String,dynamic>{'assessment_type':f['type']!.text,'question_text':f['question']!.text,'option_a':f['a']!.text,'option_b':f['b']!.text,'option_c':f['c']!.text,'option_d':f['d']!.text,'correct_option':correct,'marks':double.tryParse(f['marks']!.text)??1,'sort_order':int.tryParse(f['order']!.text)??questions.length+1};if(d['question_text']==''||['option_a','option_b','option_c','option_d'].any((k)=>d[k]==''))throw Exception('Enter the question and all four options.');if(q==null)await db.schema('interview').from('questions').insert(d);else await db.schema('interview').from('questions').update(d).eq('id',q['id']);await open('Questions');note('Question saved.');}}catch(e){showError(clean(e));}finally{for(final c in f.values){c.dispose();}}
  }
  Future<void> deleteQuestion(Map<String,dynamic> q)async{if(await confirm('Delete question?','Linked answers will also be deleted.')!=true)return;try{await db.schema('interview').from('questions').delete().eq('id',q['id']);await open('Questions');}catch(e){showError(clean(e));}}
  Widget trackingPage()=>ListView(padding:const EdgeInsets.all(12),children:[Row(children:[Expanded(child:Text('Page activity',style:Theme.of(context).textTheme.titleLarge)),IconButton(onPressed:()=>open('Tracking'),icon:const Icon(Icons.refresh))]),if(activity.isEmpty)const Text('No activity records found.'),for(final a in activity)Card(child:ListTile(title:Text((a['username']??'Unknown').toString()+' · '+(a['visited_page']??a['page_name']??'Page').toString()),subtitle:Text((a['email']??'').toString()+' · '+(a['visit_time']??'').toString()+' · '+(a['browser']??'').toString()+' · '+(a['os']??'').toString())))]);
  Widget contentPage(){final about=TextEditingController(text:company?['about']?.toString()??'');final instructions=TextEditingController(text:company?['instructions']?.toString()??'');final duration=TextEditingController(text:(company?['duration_minutes']??30).toString());return ListView(padding:const EdgeInsets.all(14),children:[Text('Company content and settings',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:10),TextField(controller:about,maxLines:6,decoration:const InputDecoration(labelText:'About')),const SizedBox(height:10),TextField(controller:instructions,maxLines:6,decoration:const InputDecoration(labelText:'Instructions')),const SizedBox(height:10),TextField(controller:duration,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Duration in minutes')),const SizedBox(height:12),FilledButton(onPressed:()async{try{await db.schema('interview').from('company_info').update({'about':about.text,'instructions':instructions.text,'duration_minutes':int.tryParse(duration.text)??30}).eq('id',1);await refreshData();note('Content saved.');}catch(e){showError(clean(e));}},child:const Text('Save content'))]);}
  Future<bool?> confirm(String title,String body)=>showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(title),content:Text(body),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Continue'))]));
  void showError(String s){if(mounted)showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Interview'),content:Text(s),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('OK'))]));}
}
