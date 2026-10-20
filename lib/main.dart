import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        ])))))));
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
  bool favoritesOnly = false, loading = true, cloudError = false, searchExpanded = false;
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

  void openApp(DeckApp app, {bool admin = false}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AppWorkspaceScreen(app: app, admin: admin),
    ));
  }

  Future<void> editApp([DeckApp? old]) async {
    final name = TextEditingController(text: old?.name ?? '');
    final description = TextEditingController(text: old?.description ?? '');
    String cat = old?.category ?? 'Personal', icon = old?.iconKey ?? 'apps';
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Text(old == null ? 'Add an app workspace' : 'Edit ' + old.name),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'App name'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null),
        const SizedBox(height: 10), TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
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
        FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Save workspace'))],
    )));
    if (ok == true && mounted) {
      final isNew = old == null;
      final item = old ?? DeckApp(id: DateTime.now().microsecondsSinceEpoch.toString(), name: '', description: '',
        category: cat, url: '', iconKey: icon, accentHex: 0xFF64748B, sortOrder: apps.length);
      setState(() {
        item.name = name.text.trim(); item.description = description.text.trim(); item.category = cat;
        item.iconKey = icon;
        if (isNew) apps.add(item);
      });
      try { await _persist(item, insert: isNew); }
      catch (_) { message('Could not save to the cloud. Check the ControlDeck SQL setup.'); }
    }
    name.dispose(); description.dispose();
  }

  Future<void> toggleFavorite(DeckApp app) async {
    setState(() => app.favorite = !app.favorite);
    try { await _persist(app); } catch (_) { message('Could not sync this change to the cloud.'); }
  }

  Future<void> removeApp(DeckApp app) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Remove app shortcut?'),
      content: Text('Remove ' + app.name + ' from your ControlDeck workspace?'),
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
    final personal = apps.where((a) => a.category == 'Personal').length;
    final professional = apps.where((a) => a.category == 'Professional').length;
    return Scaffold(
      appBar: AppBar(title: wide ? const _BrandMark() : const Text('ControlDeck', style: TextStyle(fontWeight: FontWeight.w800)), actions: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          width: searchExpanded ? (wide ? 270 : (MediaQuery.sizeOf(context).width < 420 ? 132 : 176)) : 44,
          height: 42,
          decoration: BoxDecoration(
            color: searchExpanded ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: searchExpanded
              ? Row(children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search_rounded, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: search,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Search apps…',
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                  )),
                  IconButton(
                    tooltip: 'Close search',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() { search.clear(); searchExpanded = false; }),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ])
              : IconButton(
                  tooltip: 'Search apps',
                  onPressed: () => setState(() => searchExpanded = true),
                  icon: const Icon(Icons.search_rounded),
                ),
        ),
        if (widget.cloudUserId != null) const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Center(child: _StatusPill(label: 'Cloud synced', icon: Icons.cloud_done_rounded, color: accent))),
        IconButton(tooltip: 'Toggle theme', onPressed: () => widget.onTheme(!widget.dark), icon: Icon(widget.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
        if (widget.cloudUserId != null && MediaQuery.sizeOf(context).width >= 420) IconButton(tooltip: 'Sign out', onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout_rounded)),
        const SizedBox(width: 8),
      ]),
      body: Row(children: [
        if (wide) _SideNav(page: page, onSelect: (v) => setState(() { page = v; favoritesOnly = v == 'Favourites'; if (v == 'All apps' || v == 'Overview') category = 'All apps'; })),
        Expanded(child: CustomScrollView(slivers: [SliverPadding(padding: EdgeInsets.fromLTRB(wide ? 30 : 18, 20, wide ? 30 : 18, 32),
          sliver: SliverList(delegate: SliverChildListDelegate([
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(page == 'Overview' ? 'Your workspace, in one place.' : page, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 8), Text('Your apps, tools, and workspaces — all inside one native experience.', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ])),
              if (wide) FilledButton.icon(onPressed: () => editApp(), icon: const Icon(Icons.add_rounded), label: const Text('Add app'),
                style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16))),
            ]),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, box) {
              final cols = box.maxWidth > 1000 ? 4 : box.maxWidth > 540 ? 2 : 1;
              return GridView.count(crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12,
                childAspectRatio: cols == 1 ? 4.2 : 2.1, children: [
                  _MetricCard(label: 'App workspaces', value: apps.length.toString(), caption: 'Ready to open', icon: Icons.grid_view_rounded),
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
            _Notice(text: widget.cloudUserId != null ? 'Your shortcuts sync through Supabase. Each app keeps its own sign-in and permissions.' : 'Local mode is active. Configure Supabase to sync your workspace across devices.', icon: Icons.shield_outlined),
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

class AppWorkspaceScreen extends StatelessWidget {
  const AppWorkspaceScreen({super.key, required this.app, this.admin = false});
  final DeckApp app;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    switch (app.id.toLowerCase()) {
      case 'portfolio': return PortfolioNativeScreen(admin: admin);
      case 'notes': return const NotesNativeScreen();
      case 'interview': return const InterviewNativeScreen();
      case 'lifehub': return const LifeHubNativeScreen();
      case 'railways': return const _NativeFeatureScreen(title: 'Railways', subtitle: 'Railway workflows and operational tools', icon: Icons.train_rounded, features: ['Railway portal overview', 'Operational records', 'Data collection', 'Reports and status tracking']);
      default: return _NativeFeatureScreen(title: app.name, subtitle: app.description, icon: iconFor(app.iconKey), features: ['Overview', 'Recent activity', 'Workspace settings']);
    }
  }
}

const _portfolioUrl = 'https://ixjdjvkktlzgiyojnsto.supabase.co';
const _portfolioKey = 'sb_publishable_Qb66X-cvzAckaQev2ku1VA__CoLmIB1';
const _lifeHubUrl = 'https://wrssvnvagpnvlwhnqqta.supabase.co';
const _lifeHubKey = 'sb_publishable_AEu-JBRYrCLYrVq3VjAtyA_ya5ApyM';
const _notesUrl = String.fromEnvironment('NOTES_SUPABASE_URL');
const _notesKey = String.fromEnvironment('NOTES_SUPABASE_ANON_KEY');
const _interviewUrl = String.fromEnvironment('INTERVIEW_SUPABASE_URL');
const _interviewKey = String.fromEnvironment('INTERVIEW_SUPABASE_ANON_KEY');

class _NativeFeatureScreen extends StatelessWidget {
  const _NativeFeatureScreen({required this.title, required this.subtitle, required this.icon, required this.features});
  final String title, subtitle;
  final IconData icon;
  final List<String> features;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)), title: Text(title)),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 960), child: ListView(padding: const EdgeInsets.all(20), children: [
      _WorkspaceHero(title: title, subtitle: subtitle, icon: icon),
      const SizedBox(height: 20),
      Text('Workspace modules', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth > 700 ? 2 : 1;
        return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: cols == 1 ? 4.2 : 3.4,
          children: features.map((f) => Card(child: ListTile(leading: const Icon(Icons.widgets_outlined), title: Text(f), subtitle: const Text('Native ControlDeck workspace')))).toList());
      }),
    ]))),
  );
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({required this.title, required this.subtitle, required this.icon});
  final String title, subtitle;
  final IconData icon;
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(width: double.infinity, padding: const EdgeInsets.all(22), decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(colors: [accent.withValues(alpha: .18), theme.colorScheme.surfaceContainerHighest]),
    ), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 54, height: 54, decoration: BoxDecoration(color: accent.withValues(alpha: .18), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: accent, size: 28)),
      const SizedBox(height: 18),
      Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]));
  }
}

class PortfolioNativeScreen extends StatefulWidget {
  const PortfolioNativeScreen({super.key, this.admin = false});
  final bool admin;
  @override State<PortfolioNativeScreen> createState() => _PortfolioNativeScreenState();
}
class _PortfolioNativeScreenState extends State<PortfolioNativeScreen> {
  late final SupabaseClient client = SupabaseClient(_portfolioUrl, _portfolioKey);
  bool loading = true;
  String? error;
  Map<String, List<Map<String, dynamic>>> data = {};
  String section = 'Overview';
  final sections = const ['Overview', 'Skills', 'Projects', 'Experience', 'Education', 'Social'];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final db = client.schema('portfolio');
      final results = await Future.wait([
        db.from('site_profile').select('*').limit(1),
        db.from('languages').select('*').order('sort_order'),
        db.from('skills').select('*').order('sort_order'),
        db.from('projects').select('*').order('sort_order'),
        db.from('experience').select('*').order('sort_order'),
        db.from('education').select('*').order('sort_order'),
        db.from('social_links').select('*').order('sort_order'),
      ]);
      final keys = ['profile','languages','skills','projects','experience','education','social'];
      final next = <String, List<Map<String, dynamic>>>{};
      for (var i = 0; i < results.length; i++) {
        final value = results[i] as List;
        next[keys[i]] = value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (mounted) setState(() { data = next; loading = false; });
    } catch (e) { if (mounted) setState(() { error = e.toString(); loading = false; }); }
  }
  @override Widget build(BuildContext context) {
    final profile = data['profile']?.firstOrNull ?? {};
    final name = (profile['full_name'] ?? 'Aman Jain').toString();
    return Scaffold(
      appBar: AppBar(leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)),
        title: Text(widget.admin ? 'Portfolio Admin' : 'Portfolio', style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(tooltip: 'Refresh portfolio data', onPressed: load, icon: const Icon(Icons.refresh_rounded)), const SizedBox(width: 8)]),
      body: loading ? const Center(child: CircularProgressIndicator()) : error != null
        ? _ConnectionNotice(title: 'Portfolio data could not load', detail: error!, onRetry: load)
        : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1050), child: ListView(padding: const EdgeInsets.all(20), children: [
          _WorkspaceHero(title: name, subtitle: (profile['headline'] ?? profile['about'] ?? 'Full Stack Developer · Consultant & Data Analyst').toString(), icon: Icons.person_rounded),
          const SizedBox(height: 16),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: sections.map((s) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(s), selected: section == s, onSelected: (_) => setState(() => section = s))).toList())),
          const SizedBox(height: 18),
          if (section == 'Overview') ...[
            _DataSection(title: 'Technical skills', rows: (data['skills'] ?? []).where((e) => e['category'] == 'technical').take(8).map((e) => _dataText(e, ['name','description','percent'])).toList()),
            _DataSection(title: 'Selected projects', rows: (data['projects'] ?? []).take(8).map((e) => _dataText(e, ['title','summary','tech_stack'])).toList()),
          ] else if (section == 'Skills')
            _DataSection(title: 'Skills and languages', rows: [...(data['skills'] ?? []), ...(data['languages'] ?? [])].map((e) => _dataText(e, ['name','category','description','level','percent'])).toList())
          else if (section == 'Projects')
            _DataSection(title: 'Projects', rows: (data['projects'] ?? []).map((e) => _dataText(e, ['title','summary','tech_stack'])).toList())
          else if (section == 'Experience')
            _DataSection(title: 'Work experience', rows: (data['experience'] ?? []).map((e) => _dataText(e, ['period','title','company','details'])).toList())
          else if (section == 'Education')
            _DataSection(title: 'Education', rows: (data['education'] ?? []).map((e) => _dataText(e, ['period','title','location','details'])).toList())
          else
            _DataSection(title: 'Social links', rows: (data['social'] ?? []).map((e) => _dataText(e, ['label','url'])).toList()),
        ]))),
    );
  }
  Map<String, dynamic> _dataText(Map<String, dynamic> row, List<String> keys) {
    final out = <String, dynamic>{};
    for (final k in keys) { final v = row[k]; if (v != null && v.toString().trim().isNotEmpty) out[k] = v; }
    return out;
  }
}

class NotesNativeScreen extends StatefulWidget {
  const NotesNativeScreen({super.key});
  @override State<NotesNativeScreen> createState() => _NotesNativeScreenState();
}
class _NotesNativeScreenState extends State<NotesNativeScreen> {
  SupabaseClient? client;
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> languages = [], topics = [];
  Map<String, dynamic>? selectedLanguage, selectedTopic;
  List<dynamic> lesson = [];
  @override void initState() { super.initState(); if (_notesUrl.isNotEmpty && _notesKey.isNotEmpty) { client = SupabaseClient(_notesUrl, _notesKey); loadLanguages(); } }
  Future<void> loadLanguages() async {
    if (client == null) return;
    setState(() { loading = true; error = null; });
    try {
      final rows = await client!.schema('notes').from('languages').select('*').order('sort_order');
      if (mounted) setState(() { languages = List<Map<String,dynamic>>.from(rows); loading = false; });
    } catch (e) { if (mounted) setState(() { error = e.toString(); loading = false; }); }
  }
  Future<void> loadTopics(Map<String, dynamic> lang) async {
    setState(() { selectedLanguage = lang; selectedTopic = null; lesson = []; loading = true; error = null; });
    try {
      final rows = await client!.schema('notes').from('topics').select('*').eq('language_id', lang['id']).order('sort_order');
      if (mounted) setState(() { topics = List<Map<String,dynamic>>.from(rows); loading = false; });
    } catch (e) { if (mounted) setState(() { error = e.toString(); loading = false; }); }
  }
  Future<void> loadLesson(Map<String, dynamic> topic) async {
    setState(() { selectedTopic = topic; loading = true; error = null; });
    try {
      final row = await client!.schema('notes').from('topic_content').select('content').eq('topic_id', topic['id']).maybeSingle();
      if (mounted) setState(() { lesson = List<dynamic>.from(row?['content'] as List? ?? []); loading = false; });
    } catch (e) { if (mounted) setState(() { error = e.toString(); loading = false; }); }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(leading: IconButton(onPressed: () { if (selectedTopic != null) setState(() => selectedTopic = null); else if (selectedLanguage != null) setState(() => selectedLanguage = null); else Navigator.of(context).maybePop(); }, icon: const Icon(Icons.arrow_back_rounded)), title: const Text('Notes')),
      body: client == null ? _ConnectionNotice(title: 'Connect your Notes database', detail: 'The Notes main branch keeps its Supabase URL and anon key in local environment variables, not in GitHub. Run ControlDeck with --dart-define=NOTES_SUPABASE_URL=... and --dart-define=NOTES_SUPABASE_ANON_KEY=... to load your real curriculum.') :
      loading ? const Center(child: CircularProgressIndicator()) : error != null ? _ConnectionNotice(title: 'Notes could not load', detail: error!, onRetry: selectedLanguage == null ? loadLanguages : () => selectedLanguage == null ? loadLanguages() : loadTopics(selectedLanguage!)) :
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: ListView(padding: const EdgeInsets.all(20), children: [
        if (selectedTopic != null) ...[
          _WorkspaceHero(title: (selectedTopic!['title'] ?? 'Lesson').toString(), subtitle: (selectedLanguage?['name'] ?? '').toString(), icon: Icons.menu_book_rounded),
          for (final block in lesson) _LessonBlock(block: Map<String,dynamic>.from(block as Map)),
        ] else if (selectedLanguage != null) ...[
          _WorkspaceHero(title: selectedLanguage!['name'].toString(), subtitle: selectedLanguage!['description']?.toString() ?? 'Choose a lesson to start learning.', icon: Icons.code_rounded),
          for (final topic in topics) Card(child: ListTile(title: Text(topic['title'].toString()), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => loadLesson(topic))),
        ] else ...[
          _WorkspaceHero(title: 'Coding Notes', subtitle: 'Browse the database-driven programming curriculum.', icon: Icons.menu_book_rounded),
          LayoutBuilder(builder: (context, box) { final cols = box.maxWidth > 700 ? 3 : box.maxWidth > 440 ? 2 : 1; return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: cols, childAspectRatio: 2.3, crossAxisSpacing: 12, mainAxisSpacing: 12, children: languages.map((l) => Card(child: InkWell(onTap: () => loadTopics(l), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.code_rounded, color: accent), const Spacer(), Text(l['name'].toString(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), Text(l['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis)]))))).toList()); }),
        ],
      ])));
  }
}

class _LessonBlock extends StatelessWidget {
  const _LessonBlock({required this.block});
  final Map<String,dynamic> block;
  @override Widget build(BuildContext context) {
    final type = (block['type'] ?? '').toString();
    final text = (block['text'] ?? block['content'] ?? block['title'] ?? '').toString();
    if (type == 'code') return Card(child: Padding(padding: const EdgeInsets.all(14), child: SelectableText((block['code'] ?? text).toString(), style: const TextStyle(fontFamily: 'monospace'))));
    if (type == 'list') return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: (block['items'] as List? ?? []).map((v) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• ${v.toString()}')).toList())));
    if (type == 'heading') return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)));
    if (type == 'note') return Card(color: accent.withValues(alpha: .12), child: Padding(padding: const EdgeInsets.all(14), child: Text(text)));
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: SelectableText(text.isEmpty ? jsonEncode(block) : text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55)));
  }
}

class InterviewNativeScreen extends StatefulWidget {
  const InterviewNativeScreen({super.key});
  @override State<InterviewNativeScreen> createState() => _InterviewNativeScreenState();
}
class _InterviewNativeScreenState extends State<InterviewNativeScreen> {
  SupabaseClient? client;
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  String? error;
  Map<String,dynamic>? profile;
  List<Map<String,dynamic>> questions = [];
  @override void initState() { super.initState(); if (_interviewUrl.isNotEmpty && _interviewKey.isNotEmpty) client = SupabaseClient(_interviewUrl, _interviewKey); }
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  Future<void> login() async {
    if (client == null) return;
    setState(() { busy = true; error = null; });
    try {
      final rows = await client!.schema('interview').rpc('login_user', params: {'p_email': email.text.trim(), 'p_password': password.text});
      if ((rows as List).isEmpty) throw Exception('Incorrect email or password.');
      if (mounted) setState(() { profile = Map<String,dynamic>.from(rows.first as Map); busy = false; });
      await loadQuestions();
    } catch (e) { if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); busy = false; }); }
  }
  Future<void> loadQuestions() async {
    if (client == null) return;
    try {
      final rows = await client!.schema('interview').from('questions').select('id,assessment_type,question_text,option_a,option_b,option_c,option_d,marks').order('sort_order');
      if (mounted) setState(() => questions = List<Map<String,dynamic>>.from(rows));
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('Interview')),
    body: client == null ? _ConnectionNotice(title: 'Connect your Interview database', detail: 'The Interview main branch reads VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY from local environment variables. Run ControlDeck with --dart-define=INTERVIEW_SUPABASE_URL=... and --dart-define=INTERVIEW_SUPABASE_ANON_KEY=... to connect it.') :
    profile == null ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(22), children: [
      const _WorkspaceHero(title: 'Assessment portal', subtitle: 'Sign in to continue to your interview workspace.', icon: Icons.quiz_rounded),
      const SizedBox(height: 18), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
      const SizedBox(height: 12), TextField(controller: password, obscureText: true, onSubmitted: (_) => login(), decoration: const InputDecoration(labelText: 'Password')),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 16), FilledButton(onPressed: busy ? null : login, child: busy ? const CircularProgressIndicator() : const Text('Sign in')),
    ]))) : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 960), child: ListView(padding: const EdgeInsets.all(20), children: [
      _WorkspaceHero(title: 'Welcome, ${profile!['name'] ?? 'User'}', subtitle: 'Signed in · ${profile!['usertype'] ?? 'user'} account', icon: Icons.account_circle_rounded),
      const SizedBox(height: 18),
      _DataSection(title: 'Available assessment questions', rows: questions.map((q) => {'question':q['question_text'],'type':q['assessment_type'],'marks':q['marks']}).toList()),
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      OutlinedButton.icon(onPressed: () => setState(() { profile = null; questions = []; password.clear(); }), icon: const Icon(Icons.logout_rounded), label: const Text('Sign out')),
    ]))),
  );
}

class LifeHubNativeScreen extends StatefulWidget {
  const LifeHubNativeScreen({super.key});
  @override State<LifeHubNativeScreen> createState() => _LifeHubNativeScreenState();
}
class _LifeHubNativeScreenState extends State<LifeHubNativeScreen> {
  SupabaseClient client = SupabaseClient(_lifeHubUrl, _lifeHubKey);
  final email = TextEditingController(), password = TextEditingController(), taskTitle = TextEditingController();
  bool busy = false;
  String? error;
  Map<String,dynamic>? profile;
  String? sessionId;
  List<Map<String,dynamic>> tasks = [];
  @override void dispose() { email.dispose(); password.dispose(); taskTitle.dispose(); super.dispose(); }
  Future<void> login() async {
    setState(() { busy = true; error = null; });
    try {
      final result = await client.functions.invoke('custom-auth', body: {'action':'login','app':'lifehub','email':email.text.trim().toLowerCase(),'password':password.text,'page':'/'});
      final data = Map<String,dynamic>.from(result.data as Map);
      if (data['error'] != null) throw Exception(data['error'].toString());
      sessionId = data['sessionId']?.toString();
      profile = Map<String,dynamic>.from(data['profile'] as Map);
      if (sessionId != null && sessionId!.isNotEmpty) client = SupabaseClient(_lifeHubUrl, _lifeHubKey, headers: {'x-lifehub-session': sessionId!});
      if (mounted) setState(() { busy = false; });
      await loadTasks();
    } catch (e) { if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); busy = false; }); }
  }
  Future<void> loadTasks() async {
    if (profile == null) return;
    setState(() { busy = true; error = null; });
    try {
      final rows = await client.from('tasks').select('*').eq('user_id', profile!['id']).order('created_at', ascending: false);
      if (mounted) setState(() { tasks = List<Map<String,dynamic>>.from(rows); busy = false; });
    } catch (e) { if (mounted) setState(() { error = e.toString(); busy = false; }); }
  }
  Future<void> addTask() async {
    if (taskTitle.text.trim().isEmpty || profile == null) return;
    setState(() { busy = true; error = null; });
    try {
      await client.from('tasks').insert({'user_id':profile!['id'],'title':taskTitle.text.trim(),'priority':'medium','done':false});
      taskTitle.clear(); await loadTasks();
    } catch (e) { if (mounted) setState(() { error = e.toString(); busy = false; }); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('LifeHub')),
    body: profile == null ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(22), children: [
      const _WorkspaceHero(title: 'LifeHub', subtitle: 'Sign in to open your personal command centre.', icon: Icons.home_work_rounded),
      const SizedBox(height: 18), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
      const SizedBox(height: 12), TextField(controller: password, obscureText: true, onSubmitted: (_) => login(), decoration: const InputDecoration(labelText: 'Password')),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 16), FilledButton(onPressed: busy ? null : login, child: busy ? const CircularProgressIndicator() : const Text('Sign in')),
    ]))) : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 980), child: ListView(padding: const EdgeInsets.all(20), children: [
      _WorkspaceHero(title: 'Welcome, ${profile!['full_name'] ?? profile!['name'] ?? 'there'}', subtitle: 'LifeHub · Tasks and personal planning', icon: Icons.home_work_rounded),
      const SizedBox(height: 18),
      Row(children: [Expanded(child: TextField(controller: taskTitle, onSubmitted: (_) => addTask(), decoration: const InputDecoration(labelText: 'Add a task', prefixIcon: Icon(Icons.add_task_rounded)))), const SizedBox(width: 10), FilledButton(onPressed: busy ? null : addTask, child: const Text('Add'))]),
      const SizedBox(height: 14),
      _DataSection(title: 'Tasks', rows: tasks.map((t) => {'title':t['title'],'priority':t['priority'],'due date':t['due_date'],'status':t['done'] == true ? 'Done' : 'Pending'}).toList()),
      if (busy) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      OutlinedButton.icon(onPressed: () => setState(() { profile = null; tasks = []; sessionId = null; client = SupabaseClient(_lifeHubUrl, _lifeHubKey); }), icon: const Icon(Icons.logout_rounded), label: const Text('Sign out')),
    ]))),
  );
}

class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice({required this.title, required this.detail, this.onRetry});
  final String title, detail;
  final Future<void> Function()? onRetry;
  @override Widget build(BuildContext context) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 540), child: Padding(padding: const EdgeInsets.all(22), child: Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Icon(Icons.cloud_off_rounded, color: accent, size: 34), const SizedBox(height: 12),
    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 8), Text(detail, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
    if (onRetry != null) ...[const SizedBox(height: 14), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'))],
  ]))))));
}

class _DataSection extends StatelessWidget {
  const _DataSection({required this.title, required this.rows});
  final String title;
  final List<Map<String, dynamic>> rows;
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    if (rows.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No records available yet.')),
    for (final row in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text((row.values.firstOrNull ?? 'Item').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      Text(row.entries.skip(1).map((e) => '${e.key}: ${e.value}').join(' · '), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const Divider(height: 16),
    ])),
  ])));
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
        Padding(padding: const EdgeInsets.only(left: 12, bottom: 10), child: Text('WORKSPACE', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.4, color: theme.colorScheme.onSurfaceVariant))),
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
        _StatusPill(label: 'Native workspace', icon: Icons.dashboard_rounded, color: accent),
        const SizedBox(height: 5), Expanded(child: Text(app.description.isEmpty ? 'Open this workspace inside ControlDeck.' : app.description,
          maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4))),
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: Text(app.category, style: theme.textTheme.labelSmall)),
          const Spacer(), if (onAdmin != null) IconButton(tooltip: app.adminUrl.trim().isEmpty ? 'Configure Portfolio admin' : 'Open admin', onPressed: onAdmin, icon: const Icon(Icons.admin_panel_settings_outlined, size: 19)),
          FilledButton.tonalIcon(onPressed: onOpen, icon: const Icon(Icons.arrow_forward_rounded, size: 16), label: const Text('Open workspace')),
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
