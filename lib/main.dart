import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const accent = Color(0xFF8FA600);

void main() => runApp(const ControlDeckApp());

class DeckApp {
  DeckApp({required this.id, required this.name, required this.description,
    required this.category, required this.url, required this.icon,
    required this.color, this.favorite = false});
  final String id;
  String name, description, category, url;
  IconData icon;
  int color;
  bool favorite;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description, 'category': category,
    'url': url, 'icon': icon.codePoint, 'color': color, 'favorite': favorite,
  };

  factory DeckApp.fromJson(Map<String, dynamic> j) => DeckApp(
    id: j['id'] as String, name: j['name'] as String,
    description: j['description'] as String? ?? '',
    category: j['category'] as String? ?? 'Other',
    url: j['url'] as String? ?? '',
    icon: _iconFor(j['icon'] as int? ?? Icons.apps_rounded.codePoint),
    color: j['color'] as int? ?? 0xFF64748B,
    favorite: j['favorite'] as bool? ?? false,
  );
}

IconData _iconFor(int code) {
  const icons = [Icons.home_work_rounded, Icons.sticky_note_2_rounded,
    Icons.train_rounded, Icons.quiz_rounded, Icons.language_rounded,
    Icons.folder_rounded, Icons.analytics_rounded, Icons.code_rounded,
    Icons.apps_rounded];
  for (final icon in icons) { if (icon.codePoint == code) return icon; }
  return Icons.apps_rounded;
}

List<DeckApp> starterApps() => [
  DeckApp(id:'lifehub', name:'LifeHub', description:'Your personal workspace',
    category:'Personal', url:'https://amanajaina.github.io/LifeHub/',
    icon:Icons.home_work_rounded, color:0xFF8B5CF6),
  DeckApp(id:'notes', name:'Notes', description:'Ideas and quick thoughts',
    category:'Personal', url:'https://github.com/AmanJainA/Notes',
    icon:Icons.sticky_note_2_rounded, color:0xFFF59E0B),
  DeckApp(id:'railways', name:'Railways', description:'Railway tools and workflows',
    category:'Professional', url:'https://amanajaina.github.io/Railways/',
    icon:Icons.train_rounded, color:0xFF0EA5E9),
  DeckApp(id:'interview', name:'Interview', description:'Practice, tests and results',
    category:'Professional', url:'https://github.com/AmanJainA/Interview',
    icon:Icons.quiz_rounded, color:0xFF10B981),
  DeckApp(id:'portfolio', name:'Portfolio', description:'Portfolio and projects',
    category:'Creative', url:'https://amanajaina.github.io/Portfolio/',
    icon:Icons.language_rounded, color:0xFFEC4899),
];

class ControlDeckApp extends StatefulWidget {
  const ControlDeckApp({super.key});
  @override State<ControlDeckApp> createState() => _ControlDeckAppState();
}

class _ControlDeckAppState extends State<ControlDeckApp> {
  bool dark = true;
  @override Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: accent,
      brightness: dark ? Brightness.dark : Brightness.light);
    return MaterialApp(
      title:'ControlDeck', debugShowCheckedModeBanner:false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(useMaterial3:true, colorScheme:scheme,
        scaffoldBackgroundColor:const Color(0xFFF5F6F3)),
      darkTheme: ThemeData(useMaterial3:true, colorScheme:scheme,
        scaffoldBackgroundColor:const Color(0xFF0D1016)),
      home: DeckHome(dark:dark, onTheme:(v)=>setState(()=>dark=v)),
    );
  }
}

class DeckHome extends StatefulWidget {
  const DeckHome({super.key, required this.dark, required this.onTheme});
  final bool dark;
  final ValueChanged<bool> onTheme;
  @override State<DeckHome> createState()=>_DeckHomeState();
}

class _DeckHomeState extends State<DeckHome> {
  final search = TextEditingController();
  List<DeckApp> apps = starterApps();
  String category = 'All apps';
  bool favorites = false;
  static const categories = ['All apps','Personal','Professional','Creative','Administration','Other'];

  @override void initState(){ super.initState(); _load(); }
  @override void dispose(){ search.dispose(); super.dispose(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('controldeck.apps');
    if (raw == null || !mounted) return;
    try {
      final saved = (jsonDecode(raw) as List).map((e)=>
        DeckApp.fromJson(Map<String,dynamic>.from(e as Map))).toList();
      if(saved.isNotEmpty) setState(()=>apps=saved);
    } catch (_) {}
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('controldeck.apps',jsonEncode(apps.map((a)=>a.toJson()).toList()));
  }

  List<DeckApp> get shown {
    final q=search.text.trim().toLowerCase();
    return apps.where((a)=>(category=='All apps'||a.category==category) &&
      (!favorites||a.favorite) &&
      (q.isEmpty||a.name.toLowerCase().contains(q)||
       a.description.toLowerCase().contains(q)||a.category.toLowerCase().contains(q))).toList();
  }

  void message(String s)=>ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content:Text(s),behavior:SnackBarBehavior.floating));

  Future<void> openApp(DeckApp a) async {
    final uri=Uri.tryParse(a.url.trim());
    if(uri==null||!uri.hasScheme){ editApp(a); message('Add a valid URL first.'); return; }
    try { if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted) message('Could not open link.'); }
    catch(_){if(mounted) message('Could not open link. Check the URL.');}
  }

  Future<void> editApp([DeckApp? old]) async {
    final n=TextEditingController(text:old?.name??'');
    final d=TextEditingController(text:old?.description??'');
    final u=TextEditingController(text:old?.url??'');
    String c=old?.category??'Personal';
    final key=GlobalKey<FormState>();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,setDialog)=>AlertDialog(
        title:Text(old==null?'Add an app':'Edit app'),
        content:SizedBox(width:420,child:SingleChildScrollView(child:Form(key:key,child:Column(
          mainAxisSize:MainAxisSize.min,children:[
            TextFormField(controller:n,decoration:const InputDecoration(labelText:'App name'),
              validator:(v)=>v==null||v.trim().isEmpty?'Enter an app name':null),
            TextFormField(controller:d,decoration:const InputDecoration(labelText:'Description')),
            TextFormField(controller:u,decoration:const InputDecoration(labelText:'Website URL'),keyboardType:TextInputType.url),
            const SizedBox(height:12),
            DropdownButtonFormField<String>(value:c,decoration:const InputDecoration(labelText:'Category'),
              items:categories.where((x)=>x!='All apps').map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
              onChanged:(v)=>setDialog(()=>c=v??c)),
          ])))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
          FilledButton(onPressed:(){if(key.currentState!.validate())Navigator.pop(ctx,true);},child:const Text('Save')),
        ],
      )));
    if(ok==true&&mounted){
      setState((){
        if(old==null){apps.add(DeckApp(id:DateTime.now().microsecondsSinceEpoch.toString(),
          name:n.text.trim(),description:d.text.trim(),category:c,url:u.text.trim(),
          icon:Icons.apps_rounded,color:0xFF64748B));}
        else {old.name=n.text.trim();old.description=d.text.trim();old.category=c;old.url=u.text.trim();}
      });
      await _save();
    }
    n.dispose();d.dispose();u.dispose();
  }

  Future<void> toggle(DeckApp a) async {setState(()=>a.favorite=!a.favorite);await _save();}
  Future<void> remove(DeckApp a) async {setState(()=>apps.removeWhere((x)=>x.id==a.id));await _save();}

  @override Widget build(BuildContext context) {
    final t=Theme.of(context); final wide=MediaQuery.sizeOf(context).width>=760;
    return Scaffold(
      appBar:AppBar(title:Row(children:[
        Container(width:38,height:38,decoration:BoxDecoration(color:accent.withValues(alpha:.17),borderRadius:BorderRadius.circular(12)),
          child:const Icon(Icons.hub_rounded,color:accent)),
        const SizedBox(width:12),const Text('ControlDeck',style:TextStyle(fontWeight:FontWeight.w800)),
      ]),actions:[IconButton(tooltip:'Switch theme',onPressed:()=>widget.onTheme(!widget.dark),
        icon:Icon(widget.dark?Icons.light_mode_rounded:Icons.dark_mode_rounded)),const SizedBox(width:12)]),
      floatingActionButton:FloatingActionButton.extended(onPressed:()=>editApp(),icon:const Icon(Icons.add),label:const Text('Add app')),
      body:Row(children:[
        if(wide) SizedBox(width:220,child:Container(
          decoration:BoxDecoration(border:Border(right:BorderSide(color:t.colorScheme.outlineVariant))),
          padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const SizedBox(height:14),Text('WORKSPACE',style:t.textTheme.labelSmall?.copyWith(letterSpacing:1.5)),
            const SizedBox(height:12),...categories.map((c)=>ListTile(dense:true,
              selected:category==c&&!favorites,selectedTileColor:accent.withValues(alpha:.15),
              leading:Icon(c=='All apps'?Icons.grid_view_rounded:c=='Personal'?Icons.person_rounded:
                c=='Professional'?Icons.work_rounded:c=='Creative'?Icons.palette_rounded:Icons.folder_rounded,size:20),
              title:Text(c),onTap:()=>setState(()=>{category=c,favorites=false}))),
            const Divider(),ListTile(dense:true,selected:favorites,leading:const Icon(Icons.favorite),
              title:const Text('Favourites'),onTap:()=>setState(()=>favorites=!favorites)),
            const Spacer(),Text('CONTROLDECK  •  1.0',style:t.textTheme.labelSmall),
          ]))),
        Expanded(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1240),
          child:ListView(padding:EdgeInsets.fromLTRB(wide?30:18,20,wide?30:18,100),children:[
            Container(padding:const EdgeInsets.all(26),decoration:BoxDecoration(
              gradient:LinearGradient(colors:widget.dark?const [Color(0xFF202A22),Color(0xFF191A27)]:const [Color(0xFFEEF4D7),Color(0xFFF0EDFA)]),
              borderRadius:BorderRadius.circular(24),border:Border.all(color:t.colorScheme.outlineVariant)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.bolt_rounded,color:accent,size:17),SizedBox(width:6),Text('YOUR DIGITAL COMMAND CENTRE',style:TextStyle(fontSize:11,letterSpacing:1,fontWeight:FontWeight.w800))]),
                const SizedBox(height:16),Text('Everything you use.\nOne place to start.',style:t.textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w900,letterSpacing:-1,height:1.08)),
                const SizedBox(height:10),Text('Your personal, professional and creative tools — organised around the way you work.',style:t.textTheme.bodyMedium?.copyWith(color:t.colorScheme.onSurfaceVariant)),
                const SizedBox(height:20),Wrap(spacing:20,runSpacing:8,children:[
                  _stat(Icons.apps_rounded,apps.length.toString(),'connected apps',t),
                  _stat(Icons.favorite_rounded,apps.where((a)=>a.favorite).length.toString(),'favourites',t),
                  _stat(Icons.add_circle_outline_rounded,'∞','room to grow',t),
                ]),
              ]),
            ),
            const SizedBox(height:22),
            TextField(controller:search,onChanged:(_)=>setState((){}),decoration:InputDecoration(
              hintText:'Search apps, tools or categories...',prefixIcon:const Icon(Icons.search_rounded),
              suffixIcon:search.text.isEmpty?null:IconButton(onPressed:(){search.clear();setState((){});},icon:const Icon(Icons.close)),
              filled:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none))),
            if(!wide) Padding(padding:const EdgeInsets.only(top:16),child:Wrap(spacing:7,runSpacing:7,children:[
              ...categories.map((c)=>ChoiceChip(label:Text(c),selected:category==c&&!favorites,onSelected:(_)=>setState(()=>{category=c,favorites=false}))),
              FilterChip(label:const Text('Favourites'),selected:favorites,onSelected:(v)=>setState(()=>favorites=v)),
            ])),
            const SizedBox(height:24),
            Row(children:[Expanded(child:Text(favorites?'Your favourites':'Your apps',style:t.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800))),
              Text(shown.length.toString()+' apps',style:t.textTheme.bodySmall)]),
            const SizedBox(height:14),
            if(shown.isEmpty) Center(child:Padding(padding:const EdgeInsets.all(32),child:Column(children:[
              const Icon(Icons.search_off_rounded,size:42,color:accent),const SizedBox(height:12),
              Text('Nothing here yet',style:t.textTheme.titleLarge),const SizedBox(height:8),
              const Text('Try another search or add a tool.'),const SizedBox(height:12),
              FilledButton.icon(onPressed:()=>editApp(),icon:const Icon(Icons.add),label:const Text('Add an app')),
            ]))) else LayoutBuilder(builder:(ctx,box){
              final count=box.maxWidth>=1000?4:box.maxWidth>=650?3:box.maxWidth>=420?2:1;
              return GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:shown.length,
                gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:count,crossAxisSpacing:14,mainAxisSpacing:14,mainAxisExtent:188),
                itemBuilder:(ctx,i)=>_card(shown[i],t));
            }),
            const SizedBox(height:24),Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(
              color:t.colorScheme.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:t.colorScheme.outlineVariant)),
              child:const Row(children:[Icon(Icons.lock_outline_rounded,color:accent,size:18),SizedBox(width:10),
                Expanded(child:Text('Your app list is saved on this device. Linked apps open in your browser.'))])),
          ])))),
      ]),
    );
  }

  Widget _stat(IconData icon,String value,String label,ThemeData t)=>Row(mainAxisSize:MainAxisSize.min,children:[
    Icon(icon,size:17,color:accent),const SizedBox(width:6),Text(value,style:t.textTheme.titleSmall?.copyWith(fontWeight:FontWeight.w900)),
    const SizedBox(width:5),Text(label,style:t.textTheme.bodySmall?.copyWith(color:t.colorScheme.onSurfaceVariant))]);

  Widget _card(DeckApp a,ThemeData t){
    final c=Color(a.color);
    return Material(color:t.colorScheme.surface,borderRadius:BorderRadius.circular(20),child:InkWell(
      onTap:()=>openApp(a),borderRadius:BorderRadius.circular(20),child:Container(padding:const EdgeInsets.all(16),
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),border:Border.all(color:t.colorScheme.outlineVariant)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(width:48,height:48,decoration:BoxDecoration(color:c.withValues(alpha:.15),borderRadius:BorderRadius.circular(15)),
              child:Icon(a.icon,color:c,size:24)),const Spacer(),
            IconButton(tooltip:'Toggle favourite',onPressed:()=>toggle(a),icon:Icon(a.favorite?Icons.favorite:Icons.favorite_border,
              color:a.favorite?Colors.pinkAccent:null)),
            PopupMenuButton<String>(onSelected:(v){if(v=='edit')editApp(a);if(v=='remove')remove(a);},
              itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('Edit app')),PopupMenuItem(value:'remove',child:Text('Remove app'))]),
          ]),
          const Spacer(),Text(a.name,maxLines:1,overflow:TextOverflow.ellipsis,style:t.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),
          const SizedBox(height:4),Text(a.description.isEmpty?'Add a description':a.description,maxLines:1,overflow:TextOverflow.ellipsis,
            style:t.textTheme.bodySmall?.copyWith(color:t.colorScheme.onSurfaceVariant)),
          const SizedBox(height:12),Row(children:[Container(width:6,height:6,decoration:BoxDecoration(color:c,shape:BoxShape.circle)),
            const SizedBox(width:7),Expanded(child:Text(a.url.isEmpty?'Setup required':a.category,style:t.textTheme.labelSmall?.copyWith(color:t.colorScheme.onSurfaceVariant))),
            Icon(Icons.arrow_outward_rounded,size:16,color:t.colorScheme.onSurfaceVariant)]),
        ]))));
  }
}
