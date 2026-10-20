import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const accent = Color(0xFF8FA600);
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const cloudEnabled = supabaseUrl != '' && supabaseAnonKey != '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (cloudEnabled) await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const ControlDeckApp());
}

class DeckApp {
  DeckApp({required this.id, required this.name, required this.description, required this.category,
    required this.url, this.adminUrl = '', this.iconKey = 'apps', this.accentHex = 0xFF64748B,
    this.favorite = false, this.sortOrder = 0});

  final String id;
  String name, description, category, url, adminUrl, iconKey;
  int accentHex, sortOrder;
  bool favorite;

  bool get isConnected => url.trim().isNotEmpty;

  Map<String, dynamic> toJson({String? ownerId}) => {
    'id': id, if (ownerId != null) 'owner_id': ownerId, 'name': name, 'description': description,
    'category': category, 'url': url, 'admin_url': adminUrl, 'icon_key': iconKey,
    'accent_hex': accentHex, 'is_favorite': favorite, 'sort_order': sortOrder,
  };

  factory DeckApp.fromJson(Map<String, dynamic> j) => DeckApp(
    id: j['id'].toString(), name: j['name'] as String? ?? 'Untitled app',
    description: j['description'] as String? ?? '', category: j['category'] as String? ?? 'Other',
    url: j['url'] as String? ?? '', adminUrl: j['admin_url'] as String? ?? '',
    iconKey: j['icon_key'] as String? ?? 'apps',
    accentHex: (j['accent_hex'] as num?)?.toInt() ?? 0xFF64748B,
    favorite: j['is_favorite'] as bool? ?? j['favorite'] as bool? ?? false,
    sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
  );
}

IconData iconFor(String key) {
  switch (key) {
    case 'lifehub': return Icons.home_work_rounded;
    case 'notes': return Icons.sticky_note_2_rounded;
    case 'railways': return Icons.train_rounded;
    case 'interview': return Icons.quiz_rounded;
    case 'portfolio': return Icons.language_rounded;
    case 'admin': return Icons.admin_panel_settings_rounded;
    case 'analytics': return Icons.query_stats_rounded;
    case 'code': return Icons.code_rounded;
    default: return Icons.apps_rounded;
  }
}

List<DeckApp> starterApps() => [
  DeckApp(id: 'lifehub', name: 'LifeHub', description: 'Personal workspace, notes and daily planning',
    category: 'Personal', url: '', iconKey: 'lifehub', accentHex: 0xFF8B5CF6, sortOrder: 0),
  DeckApp(id: 'notes', name: 'Notes', description: 'Capture ideas and keep your knowledge organised',
    category: 'Personal', url: '', iconKey: 'notes', accentHex: 0xFFF59E0B, sortOrder: 1),
  DeckApp(id: 'railways', name: 'Railways', description: 'Railway portal and operational workflows',
    category: 'Professional', url: '', iconKey: 'railways', accentHex: 0xFF0EA5E9, sortOrder: 2),
  DeckApp(id: 'interview', name: 'Interview', description: 'Practice, assessments and interview results',
    category: 'Professional', url: '', iconKey: 'interview', accentHex: 0xFF10B981, sortOrder: 3),
  DeckApp(id: 'portfolio', name: 'Portfolio', description: 'Personal portfolio and project showcase',
    category: 'Creative', url: '', adminUrl: '', iconKey: 'portfolio', accentHex: 0xFFEC4899, sortOrder: 4),
];

class ControlDeckApp extends StatefulWidget {
  const ControlDeckApp({super.key});
  @override State<ControlDeckApp> createState() => _ControlDeckAppState();
}

class _ControlDeckAppState extends State<ControlDeckApp> {
  bool dark = true;
  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: dark ? Brightness.dark : Brightness.light);
    return MaterialApp(
      title: 'ControlDeck', debugShowCheckedModeBanner: false, themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: const Color(0xFFF5F6F3),
        cardTheme: const CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFFEEF0E9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
      darkTheme: ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: const Color(0xFF0D1016),
        cardTheme: const CardThemeData(color: Color(0xFF151A22), elevation: 0, margin: EdgeInsets.zero),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF1A202A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
      home: cloudEnabled ? AuthGate(dark: dark, onTheme: (v) => setState(() => dark = v))
        : DeckHome(dark: dark, onTheme: (v) => setState(() => dark = v)),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.dark, required this.onTheme});
  final bool dark;
  final ValueChanged<bool> onTheme;
  @override Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) {
      final user = Supabase.instance.client.auth.currentUser;
      return user == null ? SignInScreen(dark: dark, onTheme: onTheme)
        : DeckHome(dark: dark, onTheme: onTheme, cloudUserId: user.id);
    });
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.dark, required this.onTheme});
  final bool dark;
  final ValueChanged<bool> onTheme;
  @override State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final email = TextEditingController(), password = TextEditingController();
  bool creating = false, busy = false;
  String? errorText;
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.length < 6) {
      setState(() => errorText = 'Enter your email and a password with at least 6 characters.'); return;
    }
    setState(() { busy = true; errorText = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (creating) {
        await auth.signUp(email: email.text.trim(), password: password.text);
        if (mounted) setState(() => errorText = 'Account request sent. Verify your email if confirmation is enabled, then sign in.');
      } else {
        await auth.signInWithPassword(email: email.text.trim(), password: password.text);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => errorText = e.message);
    } catch (_) {
      if (mounted) setState(() => errorText = 'Connection failed. Check your Supabase settings and try again.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(padding: const EdgeInsets.all(24), child: Card(child: Padding(padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _BrandMark(), const SizedBox(height: 24),
          Text(creating ? 'Create your account' : 'Welcome back', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8), Text('Sign in to sync your app hub across devices.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 22),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded))),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true, onSubmitted: (_) => submit(), decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded))),
          if (errorText != null) ...[const SizedBox(height: 12), Text(errorText!, style: TextStyle(color: theme.colorScheme.error))],
          const SizedBox(height: 18),
          FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(creating ? 'Create account' : 'Sign in')),
          TextButton(onPressed: () => setState(() { creating = !creating; errorText = null; }),
            child: Text(creating ? 'Already have an account? Sign in' : 'New to ControlDeck? Create account')),
          Align(alignment: Alignment.centerRight, child: IconButton(onPressed: () => widget.onTheme(!widget.dark),
            tooltip: 'Toggle theme', icon: Icon(widget.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded))),
        ]))))));
  }
}

class DeckHome extends StatefulWidget {
  const DeckHome({super.key, required this.dark, required this.onTheme, this.cloudUserId});
  final bool dark;
  final ValueChanged<bool> onTheme;
  final String? cloudUserId;
  @override State<DeckHome> createState() => _DeckHomeState();
}

class _DeckHomeState extends State<DeckHome> {
  final search = TextEditingController();
  List<DeckApp> apps = starterApps();
  String category = 'All apps', page = 'Overview';
  bool favoritesOnly = false, loading = true, cloudError = false;
  static const categories = ['All apps', 'Personal', 'Professional', 'Creative', 'Administration', 'Other'];

  @override void initState() { super.initState(); search.addListener(_refresh); _load(); }
  @override void dispose() { search.removeListener(_refresh); search.dispose(); super.dispose(); }
  void _refresh() { if (mounted) setState(() {}); }

  Future<void> _load() async {
    try {
      if (widget.cloudUserId != null) {
        final client = Supabase.instance.client;
        final data = await client.from('controldeck_apps').select().order('sort_order').order('name');
        if (data.isEmpty) {
          final seeds = starterApps();
          await client.from('controldeck_apps').insert(seeds.map((a) => a.toJson(ownerId: widget.cloudUserId)).toList());
          if (mounted) setState(() => apps = seeds);
        } else if (mounted) {
          setState(() => apps = data.map((e) => DeckApp.fromJson(Map<String, dynamic>.from(e))).toList());
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('controldeck.apps');
        if (raw != null) {
          final saved = (jsonDecode(raw) as List).map((e) => DeckApp.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          if (saved.isNotEmpty && mounted) setState(() => apps = saved);
        }
      }
    } catch (_) {
      cloudError = widget.cloudUserId != null;
      if (cloudError && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud database not ready. Follow the SQL setup in the repository README.')));
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('controldeck.apps', jsonEncode(apps.map((a) => a.toJson()).toList()));
  }

  Future<void> _persist(DeckApp app, {bool insert = false, bool delete = false}) async {
    if (widget.cloudUserId != null) {
      final client = Supabase.instance.client;
      if (delete) {
        await client.from('controldeck_apps').delete().eq('id', app.id).eq('owner_id', widget.cloudUserId!);
      } else if (insert) {
        await client.from('controldeck_apps').insert(app.toJson(ownerId: widget.cloudUserId));
      } else {
        await client.from('controldeck_apps').update(app.toJson(ownerId: widget.cloudUserId)).eq('id', app.id).eq('owner_id', widget.cloudUserId!);
      }
    } else { await _saveLocal(); }
  }

  List<DeckApp> get shown {
    final q = search.text.trim().toLowerCase();
    return apps.where((a) => (category == 'All apps' || a.category == category) &&
      (!favoritesOnly || a.favorite) && (q.isEmpty || a.name.toLowerCase().contains(q) ||
      a.description.toLowerCase().contains(q) || a.category.toLowerCase().contains(q))).toList();
  }

  void message(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), behavior: SnackBarBehavior.floating));

  Future<void> openUrl(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || !(uri.scheme == 'https' || uri.scheme == 'http')) { message('Add a valid http or https URL first.'); return; }
    try { if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) message('Could not open this link.'); }
    catch (_) { if (mounted) message('Could not open this link.'); }
  }

  Future<void> openApp(DeckApp app, {bool admin = false}) async {
    final target = admin ? app.adminUrl : app.url;
    if (target.trim().isEmpty) {
      await editApp(app);
      if (mounted && admin) message('Add the admin URL to enable the Portfolio admin shortcut.');
      return;
    }
    await openUrl(target);
  }

  Future<void> editApp([DeckApp? old]) async {
    final name = TextEditingController(text: old?.name ?? '');
    final description = TextEditingController(text: old?.description ?? '');
    final url = TextEditingController(text: old?.url ?? '');
    final adminUrl = TextEditingController(text: old?.adminUrl ?? '');
    String cat = old?.category ?? 'Personal', icon = old?.iconKey ?? 'apps';
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Text(old == null ? 'Add an app' : (old.url.trim().isEmpty ? 'Connect ' + old.name : 'Edit ' + old.name)),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'App name'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null),
        const SizedBox(height: 10), TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 10), TextFormField(controller: url, decoration: const InputDecoration(labelText: 'App URL'), keyboardType: TextInputType.url, validator: (v) => v == null || v.trim().isEmpty ? 'Enter the app URL' : null),
        const SizedBox(height: 10), TextFormField(controller: adminUrl, decoration: const InputDecoration(labelText: 'Admin URL (optional)'), keyboardType: TextInputType.url),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: categories.contains(cat) && cat != 'All apps' ? cat : 'Other', decoration: const InputDecoration(labelText: 'Category'),
          items: categories.where((x) => x != 'All apps').map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setDialog(() => cat = v ?? cat)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: icon, decoration: const InputDecoration(labelText: 'Icon'),
          items: const [DropdownMenuItem(value: 'apps', child: Text('Apps')), DropdownMenuItem(value: 'lifehub', child: Text('LifeHub')),
            DropdownMenuItem(value: 'notes', child: Text('Notes')), DropdownMenuItem(value: 'railways', child: Text('Railways')),
            DropdownMenuItem(value: 'interview', child: Text('Interview')), DropdownMenuItem(value: 'portfolio', child: Text('Portfolio')),
            DropdownMenuItem(value: 'admin', child: Text('Admin')), DropdownMenuItem(value: 'analytics', child: Text('Analytics')),
            DropdownMenuItem(value: 'code', child: Text('Code'))], onChanged: (v) => setDialog(() => icon = v ?? icon)),
      ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: Text(old != null && old.url.trim().isEmpty ? 'Save connection' : 'Save app'))],
    )));
    if (ok == true && mounted) {
      final isNew = old == null;
      final item = old ?? DeckApp(id: DateTime.now().microsecondsSinceEpoch.toString(), name: '', description: '',
        category: cat, url: '', iconKey: icon, accentHex: 0xFF64748B, sortOrder: apps.length);
      setState(() {
        item.name = name.text.trim(); item.description = description.text.trim(); item.category = cat;
        item.url = url.text.trim(); item.adminUrl = adminUrl.text.trim(); item.iconKey = icon;
        if (isNew) apps.add(item);
      });
      try { await _persist(item, insert: isNew); }
      catch (_) { message('Could not save to the cloud. Check the ControlDeck SQL setup.'); }
    }
    name.dispose(); description.dispose(); url.dispose(); adminUrl.dispose();
  }

  Future<void> toggleFavorite(DeckApp app) async {
    setState(() => app.favorite = !app.favorite);
    try { await _persist(app); } catch (_) { message('Could not sync this change to the cloud.'); }
  }

  Future<void> removeApp(DeckApp app) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Remove app shortcut?'),
      content: Text('Remove ' + app.name + ' from ControlDeck? This does not delete the original website or repository.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove'))]));
    if (confirm != true) return;
    setState(() => apps.removeWhere((x) => x.id == app.id));
    try { await _persist(app, delete: true); } catch (_) { message('Could not sync removal to the cloud.'); }
  }

  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final items = shown;
    final connectedCount = apps.where((a) => a.isConnected).length;
    final personal = apps.where((a) => a.category == 'Personal').length;
    final professional = apps.where((a) => a.category == 'Professional').length;
    return Scaffold(
      appBar: AppBar(title: const _BrandMark(), actions: [
        if (widget.cloudUserId != null) const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Center(child: _StatusPill(label: 'Cloud synced', icon: Icons.cloud_done_rounded, color: accent))),
        IconButton(tooltip: 'Toggle theme', onPressed: () => widget.onTheme(!widget.dark), icon: Icon(widget.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
        if (widget.cloudUserId != null) IconButton(tooltip: 'Sign out', onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout_rounded)),
        const SizedBox(width: 8),
      ]),
      body: Row(children: [
        if (wide) _SideNav(page: page, onSelect: (v) => setState(() { page = v; favoritesOnly = v == 'Favourites'; if (v == 'All apps' || v == 'Overview') category = 'All apps'; })),
        Expanded(child: CustomScrollView(slivers: [SliverPadding(padding: EdgeInsets.fromLTRB(wide ? 30 : 18, 20, wide ? 30 : 18, 32),
          sliver: SliverList(delegate: SliverChildListDelegate([
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(page == 'Overview' ? 'Your workspace, in one place.' : page, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 8), Text('One workspace for LifeHub, Notes, Railways, Interview, and Portfolio — connect each destination when you are ready.', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ])),
              if (wide) FilledButton.icon(onPressed: () => editApp(), icon: const Icon(Icons.add_rounded), label: const Text('Add app'),
                style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16))),
            ]),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, box) {
              final cols = box.maxWidth > 1000 ? 4 : box.maxWidth > 540 ? 2 : 1;
              return GridView.count(crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12,
                childAspectRatio: cols == 1 ? 4.2 : 2.1, children: [
                  _MetricCard(label: 'Connected apps', value: connectedCount.toString(), caption: 'Ready to launch', icon: Icons.grid_view_rounded),
                  _MetricCard(label: 'Personal', value: personal.toString(), caption: 'Life and productivity', icon: Icons.home_work_rounded),
                  _MetricCard(label: 'Professional', value: professional.toString(), caption: 'Work and operations', icon: Icons.work_outline_rounded),
                  _MetricCard(label: 'Favourites', value: apps.where((a) => a.favorite).length.toString(), caption: 'Quick access shortcuts', icon: Icons.star_rounded),
                ]);
            }),
            const SizedBox(height: 28),
            if (cloudError) const Padding(padding: EdgeInsets.only(bottom: 16), child: _Notice(text: 'Cloud setup is incomplete. Run supabase/controldeck_schema.sql in your selected Supabase project, then restart ControlDeck.', icon: Icons.info_outline_rounded)),
            Row(children: [Expanded(child: Text('App library', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              Text(items.length.toString() + ' shown', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))]),
            const SizedBox(height: 14),
            TextField(controller: search, decoration: const InputDecoration(hintText: 'Search apps, tools, categories…', prefixIcon: Icon(Icons.search_rounded))),
            const SizedBox(height: 12),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              for (final c in categories) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(c), selected: category == c, onSelected: (_) => setState(() { category = c; favoritesOnly = false; }))),
              Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: const Text('Favourites'), avatar: const Icon(Icons.star_rounded, size: 16), selected: favoritesOnly, onSelected: (v) => setState(() => favoritesOnly = v))),
            ])),
            const SizedBox(height: 16),
            if (loading) const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator()))
            else if (items.isEmpty) _EmptyState(onAdd: () => editApp())
            else LayoutBuilder(builder: (context, box) {
              final cols = box.maxWidth > 1120 ? 3 : box.maxWidth > 680 ? 2 : 1;
              return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 14, mainAxisSpacing: 14, mainAxisExtent: 244),
                itemBuilder: (context, i) => _AppCard(app: items[i], onOpen: () => openApp(items[i]),
                  onAdmin: items[i].adminUrl.isEmpty && items[i].name.toLowerCase() != 'portfolio' ? null : () => openApp(items[i], admin: true),
                  onFavorite: () => toggleFavorite(items[i]), onEdit: () => editApp(items[i]), onDelete: () => removeApp(items[i])));
            }),
            if (!wide) ...[const SizedBox(height: 24), OutlinedButton.icon(onPressed: () => editApp(), icon: const Icon(Icons.add_rounded), label: const Text('Add app shortcut'))],
            const SizedBox(height: 24),
            _Notice(text: widget.cloudUserId != null ? 'Your shortcuts sync through Supabase. Each app keeps its own sign-in and permissions.' : 'Local mode is active. Configure Supabase to sync your app library across devices.', icon: Icons.shield_outlined),
          ]))),
        ])),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: page == 'Overview' ? 0 : page == 'Favourites' ? 1 : 2,
        onDestinationSelected: (i) => setState(() { page = ['Overview', 'Favourites', 'Settings'][i]; favoritesOnly = i == 1; }),
        destinations: const [NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.star_rounded), label: 'Favourites'), NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings')]),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 38, height: 38, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.dashboard_customize_rounded, color: Colors.black, size: 23)),
    const SizedBox(width: 11), const Text('ControlDeck', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.5)),
  ]);
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.page, required this.onSelect});
  final String page;
  final ValueChanged<String> onSelect;
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(width: 220, decoration: BoxDecoration(border: Border(right: BorderSide(color: theme.dividerColor.withValues(alpha: .35)))),
      padding: const EdgeInsets.fromLTRB(16, 20, 12, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 12, bottom: 10), child: Text('WORKSPACE', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.4, color: theme.colorScheme.onSurfaceVariant)),
        _NavItem(icon: Icons.dashboard_rounded, label: 'Overview', selected: page == 'Overview', onTap: () => onSelect('Overview')),
        _NavItem(icon: Icons.star_rounded, label: 'Favourites', selected: page == 'Favourites', onTap: () => onSelect('Favourites')),
        _NavItem(icon: Icons.apps_rounded, label: 'All apps', selected: page == 'All apps', onTap: () => onSelect('All apps')),
        const Spacer(), _NavItem(icon: Icons.tune_rounded, label: 'Settings', selected: page == 'Settings', onTap: () => onSelect('Settings')),
        const SizedBox(height: 8), Padding(padding: const EdgeInsets.all(12), child: Text('ONE HUB. YOUR TOOLS.', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1, color: theme.colorScheme.onSurfaceVariant))),
      ]));
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon; final String label; final bool selected; final VoidCallback onTap;
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: ListTile(dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), selected: selected, selectedTileColor: accent.withValues(alpha: .15),
      leading: Icon(icon, size: 20, color: selected ? accent : theme.colorScheme.onSurfaceVariant),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)), onTap: onTap));
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.caption, required this.icon});
  final String label, value, caption; final IconData icon;
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: accent.withValues(alpha: .13), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: accent)),
      const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 3), Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ])),
    ])));
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({required this.app, required this.onOpen, required this.onAdmin, required this.onFavorite, required this.onEdit, required this.onDelete});
  final DeckApp app; final VoidCallback onOpen, onFavorite, onEdit, onDelete; final VoidCallback? onAdmin;
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context); final tint = Color(app.accentHex);
    return Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: onOpen, child: Padding(padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: tint.withValues(alpha: .15), borderRadius: BorderRadius.circular(15)), child: Icon(iconFor(app.iconKey), color: tint, size: 25)),
          const Spacer(), IconButton(tooltip: app.favorite ? 'Remove favourite' : 'Add favourite', onPressed: onFavorite,
            icon: Icon(app.favorite ? Icons.star_rounded : Icons.star_border_rounded, color: app.favorite ? accent : theme.colorScheme.onSurfaceVariant)),
          PopupMenuButton<String>(tooltip: 'App options', onSelected: (v) { if (v == 'edit') onEdit(); if (v == 'delete') onDelete(); },
            itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit shortcut')), PopupMenuItem(value: 'delete', child: Text('Remove shortcut'))]),
        ]),
        const SizedBox(height: 14), Text(app.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        _StatusPill(label: app.isConnected ? 'Connected' : 'Not connected', icon: app.isConnected ? Icons.link_rounded : Icons.link_off_rounded, color: app.isConnected ? accent : theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 5), Expanded(child: Text(app.description.isEmpty ? 'Open this tool from your workspace.' : app.description,
          maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4))),
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: Text(app.category, style: theme.textTheme.labelSmall)),
          const Spacer(), if (onAdmin != null) IconButton(tooltip: app.adminUrl.trim().isEmpty ? 'Configure Portfolio admin' : 'Open admin', onPressed: onAdmin, icon: const Icon(Icons.admin_panel_settings_outlined, size: 19)),
          FilledButton.tonalIcon(onPressed: onOpen, icon: Icon(app.isConnected ? Icons.north_east_rounded : Icons.link_rounded, size: 16), label: Text(app.isConnected ? 'Open' : 'Connect')),
        ]),
      ]))));
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.icon, required this.color});
  final String label; final IconData icon; final Color color;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(30)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: color), const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))]));
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.icon});
  final String text; final IconData icon;
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .55), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 19, color: theme.colorScheme.onSurfaceVariant), const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4)))]));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(30), child: Column(children: [
    const Icon(Icons.widgets_outlined, size: 42), const SizedBox(height: 12),
    const Text('Nothing here yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
    const SizedBox(height: 6), const Text('Try another filter or add an app shortcut.'), const SizedBox(height: 14),
    OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Add app')),
  ]));
}
