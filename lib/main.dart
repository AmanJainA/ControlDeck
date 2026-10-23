import 'dart:convert';
import 'dart:math' as math;
import 'lifehub_workspace.dart';
import 'notes_workspace.dart';
import 'supabase_config.dart';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'railways_native_screen.dart';
import 'interview_native_screen.dart';

const accent = Color(0xFF8FA600);
const List<String> categories = ['All apps', 'Personal', 'Professional', 'Creative', 'Other'];
const supabaseUrl = SupabaseConfig.primaryUrl;
const supabaseAnonKey = SupabaseConfig.primaryKey;
const cloudEnabled = true;
const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
const String _lifeHubSessionStorageKey = 'controldeck.lifehub.session.v1';
const String _notesSessionStorageKey = 'controldeck.notes.session.v1';
const String _railwaysSessionStorageKey = 'controldeck.railways.session.v1';
const String _portfolioAdminSessionStorageKey = 'controldeck.portfolio.admin.session.v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (cloudEnabled) await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const ControlDeckApp());
}

Future<void> signOutControlDeck() async {
  final supabase = Supabase.instance.client;
  final session = supabase.auth.currentSession;
  try {
    final raw = await _secureStorage.read(key: _lifeHubSessionStorageKey);
    if (session != null && raw != null && raw.isNotEmpty) {
      final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final sessionId = saved['sessionId']?.toString();
      if (sessionId != null && sessionId.isNotEmpty) {
        await supabase.functions.invoke(
          'controldeck-sso',
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
          body: {'action': 'logout', 'app': 'lifehub', 'sessionId': sessionId},
        );
      }
    }
    final adminToken = await _secureStorage.read(key: _portfolioAdminSessionStorageKey);
    if (adminToken != null && adminToken.isNotEmpty) {
      try {
        await SupabaseClient(_portfolioUrl, _portfolioKey)
            .schema('portfolio').rpc('admin_logout', params: {'p_token': adminToken});
      } catch (_) {}
    }
  } catch (_) {}
  await _secureStorage.delete(key: _lifeHubSessionStorageKey);
  await _secureStorage.delete(key: _notesSessionStorageKey);
  await _secureStorage.delete(key: _railwaysSessionStorageKey);
  await _secureStorage.delete(key: _portfolioAdminSessionStorageKey);
  await supabase.auth.signOut();
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

// Use the bundled Font Awesome icon font for the app launcher icons. These
// glyphs are supplied by font_awesome_flutter and do not depend on remote assets.
Widget iconFor(String key) {
  switch (key) {
    case 'lifehub': return const FaIcon(FontAwesomeIcons.house);
    case 'notes': return const FaIcon(FontAwesomeIcons.noteSticky);
    case 'railways': return const FaIcon(FontAwesomeIcons.train);
    case 'interview': return const FaIcon(FontAwesomeIcons.clipboardQuestion);
    case 'portfolio': return const FaIcon(FontAwesomeIcons.globe);
    case 'admin': return const FaIcon(FontAwesomeIcons.userShield);
    case 'analytics': return const FaIcon(FontAwesomeIcons.chartLine);
    case 'code': return const FaIcon(FontAwesomeIcons.code);
    default: return const FaIcon(FontAwesomeIcons.grip);
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
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => dark = prefs.getBool('controldeck.darkTheme') ?? true);
  }

  Future<void> _setTheme(bool value) async {
    setState(() => dark = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('controldeck.darkTheme', value);
  }

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
      home: _SplashGate(dark: dark, onTheme: _setTheme, configured: cloudEnabled),
    );
  }
}

class _AuthSetupRequiredScreen extends StatelessWidget {
  const _AuthSetupRequiredScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(padding: const EdgeInsets.all(24), child: Card(
        child: Padding(padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _BrandMark(),
            const SizedBox(height: 24),
            Text('Set up secure sign-in', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text('ControlDeck requires its shared Supabase Auth project before showing your workspaces. This keeps the app from silently skipping sign-in when cloud configuration is missing.'),
            const SizedBox(height: 16),
            const _Notice(text: 'Run with SUPABASE_URL and SUPABASE_ANON_KEY configured. Create or invite your account in that project; do not store passwords or service-role keys in source code.', icon: Icons.lock_outline_rounded),
            const SizedBox(height: 16),
            SelectableText('flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
          ],
        )),
      )),
    )),
  );
}

class _SplashGate extends StatefulWidget {
  const _SplashGate({required this.dark, required this.onTheme, required this.configured});
  final bool dark;
  final ValueChanged<bool> onTheme;
  final bool configured;
  @override State<_SplashGate> createState() => _SplashGateState();
}
class _SplashGateState extends State<_SplashGate> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3300))..forward();
  bool finished = false;
  @override void initState() {
    super.initState();
    controller.addStatusListener((status) { if (status == AnimationStatus.completed && mounted) setState(() => finished = true); });
  }
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    if (finished) return widget.configured ? AuthGate(dark: widget.dark, onTheme: widget.onTheme) : const _AuthSetupRequiredScreen();
    return Scaffold(body: LayoutBuilder(builder: (context, bounds) => AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final p = controller.value;
        final dotPhase = (p / .22).clamp(0.0, 1.0);
        final symbolPhase = ((p - .18) / .34).clamp(0.0, 1.0);
        final fillPhase = ((p - .64) / .36).clamp(0.0, 1.0);
        final scale = (math.max(bounds.maxWidth, bounds.maxHeight) / 58) * 1.8 * fillPhase;
        final color = Theme.of(context).colorScheme.primary;
        return Stack(alignment: Alignment.center, children: [
          Container(color: Theme.of(context).scaffoldBackgroundColor),
          if (p >= .64) Transform.scale(scale: scale, child: Container(width: 58, height: 58, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
          if (p < .64) Transform.translate(offset: Offset(0, 12 * (1 - dotPhase) * (1 - dotPhase)),
            child: Opacity(opacity: p < .18 ? 1 : (1 - symbolPhase).clamp(0.0, 1.0),
              child: Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)))),
          if (p >= .18 && p < .9) Opacity(opacity: symbolPhase.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.7 + 0.45 * (symbolPhase < .8 ? symbolPhase / .8 : (1 - symbolPhase) / .2).clamp(0.0, 1.0),
              child: Text('@', style: TextStyle(color: color, fontSize: 76, fontWeight: FontWeight.w800, height: 1)))),
        ]);
      },
    )));
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
  final email = TextEditingController(text: 'amanjain033@gmail.com'), password = TextEditingController();
  bool creating = false, busy = false, showPassword = false;
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
              child: Card(child: Padding(padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const _BrandMark(), const SizedBox(height: 20),
                  Text(creating ? 'Create your account' : 'Welcome back', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),

                  const SizedBox(height: 18),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded))),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: !showPassword, onSubmitted: (_) => submit(), decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(tooltip: showPassword ? 'Hide password' : 'Show password', onPressed: () => setState(() => showPassword = !showPassword), icon: Icon(showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded)))),
                  if (errorText != null) ...[const SizedBox(height: 12), Text(errorText!, style: TextStyle(color: theme.colorScheme.error))],
                  const SizedBox(height: 14),
                  FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(creating ? 'Create account' : 'Sign in')),

                ])),
            )),
          ),
        )),
      ),
      ),
    );
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final wide = screenWidth >= 850;
    final compact = screenWidth < 360;
    final items = shown;
    return Scaffold(
      appBar: AppBar(title: compact ? const SizedBox(width: 4) : (wide ? const _BrandMark() : const Text('ControlDeck', style: TextStyle(fontWeight: FontWeight.w800))), actions: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          width: searchExpanded ? (wide ? 270 : (screenWidth < 360 ? 112 : screenWidth < 420 ? 132 : 176)) : 44,
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
        if (widget.cloudUserId != null && screenWidth >= 520) const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Center(child: _StatusPill(label: 'Cloud synced', icon: Icons.cloud_done_rounded, color: accent))),
        IconButton(tooltip: 'Toggle theme', onPressed: () => widget.onTheme(!widget.dark), icon: Icon(widget.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
        if (widget.cloudUserId != null && screenWidth >= 520) IconButton(tooltip: 'Sign out', onPressed: signOutControlDeck, icon: const Icon(Icons.logout_rounded)),
        if (widget.cloudUserId != null && screenWidth < 520) PopupMenuButton<String>(tooltip: 'Account options', onSelected: (value) { if (value == 'signout') signOutControlDeck(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'signout', child: Row(children: [Icon(Icons.logout_rounded), SizedBox(width: 10), Text('Sign out')]))]),
        const SizedBox(width: 8),
      ]),
      body: Row(children: [
        if (wide) _SideNav(page: page, onSelect: (v) { setState(() { page = v; favoritesOnly = false; if (v == 'All apps' || v == 'Overview') category = 'All apps'; }); }),
        Expanded(child: page == 'Profile' ? const AccountProfileScreen(embedded: true) : page == 'Settings' ? AccountSettingsScreen(dark: widget.dark, onTheme: widget.onTheme, embedded: true) : CustomScrollView(slivers: [SliverPadding(padding: EdgeInsets.fromLTRB(wide ? 30 : 18, 20, wide ? 30 : 18, 32),
          sliver: SliverList(delegate: SliverChildListDelegate([
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(page == 'Overview' ? 'ControlDeck' : page, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 8), Text('Your apps, tools, and workspaces — all inside one native experience.', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ])),

            ]),
            const SizedBox(height: 24),

            Row(children: [Expanded(child: Text('App library', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              Text(items.length.toString() + ' shown', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))]),
            const SizedBox(height: 16),
            if (loading) const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator()))
            else if (items.isEmpty) const _EmptyState()
            else LayoutBuilder(builder: (context, box) {
              final cols = box.maxWidth > 1120 ? 3 : 2;
              return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 14, mainAxisSpacing: 14, mainAxisExtent: 220),
                itemBuilder: (context, i) => _AppCard(app: items[i], onOpen: () => openApp(items[i])));
            }),

          ]))),
        ])),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: page == 'Profile' ? 1 : page == 'Settings' ? 2 : 0,
        onDestinationSelected: (i) {
          if (i == 0) setState(() { page = 'Overview'; favoritesOnly = false; category = 'All apps'; });
          if (i == 1) setState(() => page = 'Profile');
          if (i == 2) setState(() => page = 'Settings');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.account_circle_outlined), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings'),
        ]),
    );
  }
}

class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  final name = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool savingProfile = false, changingPassword = false, showPassword = false;
  String? notice, error;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    name.text = (user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'] ?? '').toString();
  }

  @override
  void dispose() {
    name.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    setState(() { savingProfile = true; notice = null; error = null; });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'full_name': name.text.trim()}),
      );
      if (mounted) setState(() => notice = 'Profile updated.');
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not update profile: $e');
    } finally {
      if (mounted) setState(() => savingProfile = false);
    }
  }

  Future<void> changePassword() async {
    if (password.text.length < 8) {
      setState(() => error = 'Use a password with at least 8 characters.');
      return;
    }
    if (password.text != confirmPassword.text) {
      setState(() => error = 'The passwords do not match.');
      return;
    }
    setState(() { changingPassword = true; notice = null; error = null; });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: password.text));
      password.clear();
      confirmPassword.clear();
      if (mounted) setState(() => notice = 'Password changed successfully.');
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not change password: $e');
    } finally {
      if (mounted) setState(() => changingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)),
        title: const Text('Profile & security'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const _WorkspaceHero(title: 'Your account', subtitle: 'Manage the profile and password used to sign in to ControlDeck.', icon: Icons.account_circle_rounded),
              const SizedBox(height: 16),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Profile details', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextFormField(initialValue: user?.email ?? '', readOnly: true, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded))),
                  const SizedBox(height: 12),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Display name', prefixIcon: Icon(Icons.person_outline_rounded))),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: savingProfile ? null : saveProfile, icon: const Icon(Icons.save_outlined), label: Text(savingProfile ? 'Saving…' : 'Save profile')),
                ],
              ))),
              const SizedBox(height: 14),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Change password', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Choose a new password. It is handled by Supabase Auth and is not stored in this app.'),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: !showPassword, decoration: InputDecoration(labelText: 'New password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => showPassword = !showPassword), icon: Icon(showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded)))),
                  const SizedBox(height: 12),
                  TextField(controller: confirmPassword, obscureText: !showPassword, onSubmitted: (_) => changePassword(), decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_reset_rounded))),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: changingPassword ? null : changePassword, icon: const Icon(Icons.password_rounded), label: Text(changingPassword ? 'Updating…' : 'Update password')),
                ],
              ))),
              if (notice != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(notice!, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600))),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: theme.colorScheme.error))),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key, required this.dark, required this.onTheme, this.embedded = false});
  final bool embedded;
  final bool dark;
  final ValueChanged<bool> onTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: embedded ? null : AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)),
        title: const Text('Settings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const _WorkspaceHero(title: 'ControlDeck settings', subtitle: 'Manage your app appearance and sign-in session.', icon: Icons.tune_rounded),
            const SizedBox(height: 16),
            Card(child: SwitchListTile(
              value: dark,
              onChanged: onTheme,
              secondary: Icon(dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
              title: const Text('Dark appearance'),
              subtitle: const Text('Switch between dark and light mode.'),
            )),
            const SizedBox(height: 12),
            Card(child: ListTile(
              leading: const Icon(Icons.security_rounded),
              title: const Text('Profile & password'),
              subtitle: const Text('Update your display name or change your password.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountProfileScreen())),
            )),
            const SizedBox(height: 12),
            Card(child: ListTile(
              leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
              title: const Text('Sign out'),
              subtitle: const Text('Sign out of ControlDeck and its connected sessions.'),
              onTap: () async {
                final accepted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text('You can sign in again with your ControlDeck account.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
                  ],
                ));
                if (accepted == true) {
                  await signOutControlDeck();
                  if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            )),
          ]),
        ),
      ),
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
      case 'portfolio': return admin ? const PortfolioAdminNativeScreen() : const PortfolioNativeScreen();
      case 'notes': return const NotesFullNativeScreen();
      case 'interview': return const InterviewNativeScreenV2();
      case 'lifehub': return const LifeHubFullNativeScreen();
      case 'railways': return const RailwaysNativeScreen();
      default: return _NativeFeatureScreen(title: app.name, subtitle: app.description, icon: iconFor(app.iconKey), features: ['Overview', 'Recent activity', 'Workspace settings']);
    }
  }
}

const _portfolioUrl = SupabaseConfig.professionalUrl;
const _portfolioKey = SupabaseConfig.professionalKey;
const _lifeHubUrl = SupabaseConfig.primaryUrl;
const _lifeHubKey = SupabaseConfig.primaryKey;
const _notesUrl = SupabaseConfig.primaryUrl;
const _notesKey = SupabaseConfig.primaryKey;
const _interviewUrl = SupabaseConfig.primaryUrl;
const _interviewKey = SupabaseConfig.primaryKey;

class _NativeFeatureScreen extends StatelessWidget {
  const _NativeFeatureScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.features,
  });

  final String title, subtitle;
  final Widget icon;
  final List<String> features;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Text(title),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _WorkspaceHero(title: title, subtitle: subtitle, icon: icon),
            const SizedBox(height: 20),
            Text(
              'Workspace modules',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, box) {
              final columns = box.maxWidth > 700 ? 2 : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 4.2 : 3.4,
                children: features.map((feature) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.widgets_outlined),
                    title: Text(feature),
                    subtitle: const Text('Native ControlDeck workspace'),
                  ),
                )).toList(),
              );
            }),
          ],
        ),
      ),
    ),
  );
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({required this.title, required this.subtitle, required this.icon});
  final String title, subtitle;
  // Accept both Material IconData and widget-based icons such as Font Awesome.
  final Object icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: .18), theme.colorScheme.surfaceContainerHighest],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: icon is IconData
                ? Icon(icon as IconData, color: accent, size: 28)
                : IconTheme(data: const IconThemeData(color: accent, size: 28), child: icon as Widget),
          ),
          const SizedBox(height: 18),
          Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
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
    final profileRows = data['profile'] ?? <Map<String, dynamic>>[];
    final profile = profileRows.isNotEmpty ? profileRows.first : <String, dynamic>{};
    final name = (profile['full_name'] ?? 'Aman Jain').toString();
    return Scaffold(
      appBar: AppBar(leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)),
        title: Text(widget.admin ? 'Portfolio Admin' : 'Portfolio', style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: 'Refresh portfolio data', onPressed: load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ]),
      body: loading ? const Center(child: CircularProgressIndicator()) : error != null
        ? _ConnectionNotice(title: 'Portfolio data could not load', detail: error!, onRetry: load)
        : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1050), child: ListView(padding: const EdgeInsets.all(20), children: [
          _WorkspaceHero(title: name, subtitle: (profile['hero_role'] ?? profile['hero_intro'] ?? profile['about_text'] ?? 'Full Stack Developer · Consultant & Data Analyst').toString(), icon: Icons.person_rounded),
          const SizedBox(height: 16),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: sections.map((s) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(s), selected: section == s, onSelected: (_) => setState(() => section = s)))).toList())),
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


class PortfolioAdminNativeScreen extends StatefulWidget {
  const PortfolioAdminNativeScreen({super.key});
  @override State<PortfolioAdminNativeScreen> createState() => _PortfolioAdminNativeScreenState();
}

class _PortfolioAdminNativeScreenState extends State<PortfolioAdminNativeScreen> {
  late final SupabaseClient client = SupabaseClient(_portfolioUrl, _portfolioKey);
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? message;
  String? token;
  String section = 'projects';
  Map<String, dynamic> data = {};

  static const resources = <Map<String, dynamic>>[
    {'key':'profile','label':'Profile','resource':'profile','fields':[
      {'key':'full_name','label':'Full name'},{'key':'username','label':'Display username'},
      {'key':'hero_role','label':'Hero role'},{'key':'profile_image_url','label':'Profile image URL'},
      {'key':'favicon_url','label':'Favicon URL'},{'key':'resume_url','label':'Resume URL'},
      {'key':'email','label':'Email'},{'key':'phone','label':'Phone'},{'key':'location','label':'Location'},
      {'key':'contact_heading','label':'Contact heading'},{'key':'contact_description','label':'Contact description','multi':true},
      {'key':'hero_intro','label':'Hero intro','multi':true},{'key':'about_text','label':'About me','multi':true}]},
    {'key':'languages','label':'Languages','resource':'language','fields':[
      {'key':'name','label':'Name'},{'key':'icon_url','label':'Icon URL'},{'key':'icon_class','label':'Icon class'},{'key':'level','label':'Level'},{'key':'sort_order','label':'Order','number':true},{'key':'is_visible','label':'Visible','bool':true}]},
    {'key':'skills','label':'Skills','resource':'skill','fields':[
      {'key':'category','label':'Category'},{'key':'name','label':'Name'},{'key':'description','label':'Description','multi':true},{'key':'percent','label':'Percent','number':true},{'key':'icon_class','label':'Icon class'},{'key':'icon_url','label':'Icon URL'},{'key':'sort_order','label':'Order','number':true},{'key':'is_visible','label':'Visible','bool':true}]},
    {'key':'projects','label':'Projects','resource':'project','fields':[
      {'key':'title','label':'Title'},{'key':'summary','label':'Summary','multi':true},{'key':'image_url','label':'Image URL'},{'key':'link','label':'Project URL'},{'key':'repo_url','label':'Repository URL'},{'key':'tech_stack','label':'Tech stack','array':true},{'key':'sort_order','label':'Order','number':true},{'key':'is_visible','label':'Visible','bool':true}]},
    {'key':'education','label':'Education','resource':'education','fields':[
      {'key':'period','label':'Period'},{'key':'location','label':'Location'},{'key':'title','label':'Title'},{'key':'details','label':'Details','multi':true,'array':true},{'key':'sort_order','label':'Order','number':true},{'key':'is_visible','label':'Visible','bool':true}]},
    {'key':'experience','label':'Work Experience','resource':'experience','fields':[
      {'key':'period','label':'Period'},{'key':'company','label':'Company'},{'key':'title','label':'Title'},{'key':'details','label':'Details','multi':true,'array':true},{'key':'sort_order','label':'Order','number':true},{'key':'is_visible','label':'Visible','bool':true}]},
    {'key':'social_links','label':'Social Platforms','resource':'social','fields':[
      {'key':'label','label':'Label'},{'key':'url','label':'URL'},{'key':'icon_class','label':'Icon class'},{'key':'sort_order','label':'Order','number':true},{'key':'is_visible','label':'Visible','bool':true}]},
    {'key':'contact','label':'Contact messages','resource':'contact','fields':[
      {'key':'created_at','label':'Received at'},{'key':'name','label':'Name'},{'key':'email','label':'Email'},
      {'key':'subject','label':'Subject'},{'key':'message','label':'Message','multi':true},
      {'key':'source','label':'Source'},{'key':'visitor_id','label':'Visitor ID'}]},
  ];

  @override void initState() { super.initState(); _restoreAdminSession(); }
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> _restoreAdminSession() async {
    try {
      final savedToken = await _secureStorage.read(key: _portfolioAdminSessionStorageKey);
      if (!mounted || savedToken == null || savedToken.isEmpty) return;
      setState(() { token = savedToken; busy = true; });
      await loadData();
    } catch (_) {
      if (mounted) setState(() { token = null; data = {}; busy = false; });
      await _secureStorage.delete(key: _portfolioAdminSessionStorageKey);
    }
  }

  Future<void> signIn() async {
    setState(() { busy = true; message = null; });
    try {
      final raw = await client.schema('portfolio').rpc('admin_login', params: {'p_email': email.text.trim(), 'p_password': password.text});
      final result = raw is List && raw.isNotEmpty ? Map<String, dynamic>.from(raw.first as Map) : Map<String, dynamic>.from(raw as Map);
      if (result['ok'] != true || result['token'] == null) throw Exception((result['message'] ?? 'Admin sign-in failed.').toString());
      token = result['token'].toString();
      await _secureStorage.write(key: _portfolioAdminSessionStorageKey, value: token);
      await loadData();
    } catch (e) {
      if (mounted) setState(() { message = e.toString().replaceFirst('Exception: ', ''); busy = false; });
    }
  }

  Future<void> loadData() async {
    if (token == null) return;
    try {
      final raw = await client.schema('portfolio').rpc('admin_get_all', params: {'p_token': token});
      if (raw is! Map) throw Exception('Unexpected response from the Portfolio admin API.');
      if (raw['ok'] == false) throw Exception((raw['message'] ?? 'Could not load Portfolio data.').toString());
      if (mounted) setState(() { data = Map<String, dynamic>.from(raw); busy = false; message = null; });
    } catch (e) {
      await _secureStorage.delete(key: _portfolioAdminSessionStorageKey);
      if (mounted) setState(() { message = e.toString().replaceFirst('Exception: ', ''); busy = false; token = null; data = {}; });
    }
  }

  Future<void> signOut() async {
    final old = token;
    setState(() { token = null; data = {}; password.clear(); });
    await _secureStorage.delete(key: _portfolioAdminSessionStorageKey);
    if (old != null) { try { await client.schema('portfolio').rpc('admin_logout', params: {'p_token': old}); } catch (_) {} }
  }

  Future<void> editRecord(Map<String, dynamic> resource, [Map<String, dynamic>? old]) async {
    final fields = List<Map<String, dynamic>>.from(resource['fields'] as List);
    final controllers = <String, TextEditingController>{};
    final boolValues = <String, bool>{};
    for (final field in fields) {
      final key = field['key'].toString();
      if (field['bool'] == true) boolValues[key] = old?[key] as bool? ?? true;
      else {
        final existing = old?[key];
        final text = existing is List ? existing.join(field['multi'] == true ? '\n' : ', ') : existing?.toString() ?? '';
        controllers[key] = TextEditingController(text: text);
      }
    }
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Text((old == null ? 'Add ' : 'Edit ') + resource['label'].toString()),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final field in fields)
          if (field['bool'] == true)
            CheckboxListTile(contentPadding: EdgeInsets.zero, title: Text(field['label'].toString()), value: boolValues[field['key']] ?? true, onChanged: (v) => setDialog(() => boolValues[field['key'].toString()] = v ?? false))
          else
            Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: controllers[field['key']], minLines: field['multi'] == true ? 2 : 1, maxLines: field['multi'] == true ? 4 : 1, keyboardType: field['number'] == true ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: field['label'].toString()))),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
    )));
    if (accepted == true && token != null) {
      final payload = <String, dynamic>{if (old?['id'] != null) 'id': old!['id']};
      for (final field in fields) {
        final key = field['key'].toString();
        if (field['bool'] == true) payload[key] = boolValues[key] ?? true;
        else {
          final value = controllers[key]!.text.trim();
          if (field['array'] == true) {
            payload[key] = value.split(field['multi'] == true ? '\n' : ',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
          } else {
            payload[key] = field['number'] == true ? (num.tryParse(value) ?? 0) : value;
          }
        }
      }
      setState(() { busy = true; message = null; });
      try {
        final result = await client.schema('portfolio').rpc(resource['key'] == 'contact' ? 'admin_contact_upsert' : resource['key'] == 'profile' ? 'admin_profile_upsert' : 'admin_upsert', params: {'p_token': token, if (resource['key'] != 'contact' && resource['key'] != 'profile') 'p_resource': resource['resource'], 'p_data': payload});
        if (result is Map && result['ok'] != true) throw Exception((result['message'] ?? 'Portfolio record could not be saved.').toString());
        await loadData();
        if (mounted && message == null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Portfolio record saved.')));
      } catch (e) { if (mounted) setState(() { busy = false; message = e.toString().replaceFirst('Exception: ', ''); }); }
    }
    for (final controller in controllers.values) { controller.dispose(); }
  }

  Future<void> deleteRecord(Map<String, dynamic> resource, Map<String, dynamic> row) async {
    if (row['id'] == null || token == null) return;
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete record?'), content: const Text('This removes the selected item from the Portfolio database.'), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
    if (accepted != true || token == null) return;
    setState(() { busy = true; message = null; });
    try {
      final result = await client.schema('portfolio').rpc('admin_delete', params: {'p_token': token, 'p_resource': resource['resource'], 'p_id': row['id']});
      if (result is Map && result['ok'] != true) throw Exception((result['message'] ?? 'Portfolio record could not be deleted.').toString());
      await loadData();
    } catch (e) { if (mounted) setState(() { busy = false; message = e.toString().replaceFirst('Exception: ', ''); }); }
  }

  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (token == null) return Scaffold(
      appBar: AppBar(leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('Portfolio Admin')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(22), children: [
        const _WorkspaceHero(title: 'Portfolio CMS', subtitle: 'Sign in to manage public portfolio content.', icon: Icons.admin_panel_settings_rounded),
        const SizedBox(height: 18), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Admin email')),
        const SizedBox(height: 12), TextField(controller: password, obscureText: true, onSubmitted: (_) => signIn(), decoration: const InputDecoration(labelText: 'Password')),
        if (message != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(message!, style: TextStyle(color: theme.colorScheme.error))),
        const SizedBox(height: 16), FilledButton(onPressed: busy ? null : signIn, child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in')),
      ]))));
    final chosen = resources.where((r) => r['key'] == section).toList();
    final current = chosen.isEmpty ? resources[2] : chosen.first;
    final rawRows = data[current['key']];
    final rows = rawRows is List
        ? List<Map<String, dynamic>>.from(rawRows.map((e) => Map<String, dynamic>.from(e as Map)))
        : rawRows is Map
            ? <Map<String, dynamic>>[Map<String, dynamic>.from(rawRows)]
            : <Map<String, dynamic>>[];
    return Scaffold(
      appBar: AppBar(leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('Portfolio Admin'), actions: [
        IconButton(tooltip: 'Refresh', onPressed: busy ? null : loadData, icon: const Icon(Icons.refresh_rounded)),
        IconButton(tooltip: 'Sign out', onPressed: signOut, icon: const Icon(Icons.logout_rounded)), const SizedBox(width: 8)]),
      body: Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [
          for (final r in resources) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(r['label'].toString()), selected: section == r['key'], onSelected: (_) => setState(() => section = r['key'].toString()))),
        ])),
        if (message != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text(message!, style: TextStyle(color: theme.colorScheme.error))),
        Expanded(child: busy ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [Expanded(child: Text(current['label'].toString(), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), if (current['key'] != 'profile' || rows.isEmpty) FilledButton.icon(onPressed: () => editRecord(current), icon: const Icon(Icons.add_rounded), label: const Text('Add'))]),
          const SizedBox(height: 12),
          if (rows.isEmpty) const _Notice(text: 'No records yet. Add the first record to this collection.', icon: Icons.inbox_outlined),
          for (final row in rows) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((row['title'] ?? row['subject'] ?? row['name'] ?? row['label'] ?? row['company'] ?? 'Untitled record').toString(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4), Text(row.entries.where((e) => e.key != 'id' && e.value != null && e.value.toString().trim().isNotEmpty).take(5).map((e) => e.key + ': ' + e.value.toString()).join(' · '), maxLines: 3, overflow: TextOverflow.ellipsis),
            Align(alignment: Alignment.centerRight, child: Wrap(spacing: 4, children: [
              IconButton(tooltip: 'Edit', onPressed: () => editRecord(current, row), icon: const Icon(Icons.edit_outlined)),
              if (current['key'] != 'profile') IconButton(tooltip: 'Delete', onPressed: () => deleteRecord(current, row), icon: const Icon(Icons.delete_outline_rounded)),
            ])),
          ]))),
        ])),
      ]),
    );
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
  @override void initState() { super.initState(); if (_notesUrl.isNotEmpty && _notesKey.isNotEmpty) { client = _notesUrl == supabaseUrl ? Supabase.instance.client : SupabaseClient(_notesUrl, _notesKey); loadLanguages(); } }
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
      ]))));
  }
}

class _LessonBlock extends StatelessWidget {
  const _LessonBlock({required this.block});
  final Map<String, dynamic> block;

  @override
  Widget build(BuildContext context) {
    final type = (block['type'] ?? '').toString();
    final text = (block['text'] ?? block['content'] ?? block['title'] ?? '').toString();
    final theme = Theme.of(context);
    if (type == 'heading') {
      return Padding(padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)));
    }
    if (type == 'subheading') {
      return Padding(padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)));
    }
    if (type == 'code') {
      final code = (block['code'] ?? text).toString();
      return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((block['filename'] ?? '').toString().isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(block['filename'].toString(), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace', height: 1.5))),
        ],
      )));
    }
    if (type == 'list') {
      final items = List<dynamic>.from(block['items'] as List? ?? const []);
      final ordered = block['ordered'] == true;
      return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < items.length; i++)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 24, child: Text(ordered ? '${i + 1}.' : '•', style: TextStyle(color: accent, fontWeight: FontWeight.w800))),
                Expanded(child: _LessonListItem(item: items[i])),
              ],
            )),
        ],
      )));
    }
    if (type == 'image') {
      final src = (block['src'] ?? '').toString();
      if (src.isEmpty) return const SizedBox.shrink();
      return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(src, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const _Notice(text: 'This lesson image could not be loaded.', icon: Icons.broken_image_outlined))),
          if ((block['caption'] ?? '').toString().isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(block['caption'].toString(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
        ],
      )));
    }
    if (type == 'table') {
      final headers = List<dynamic>.from(block['headers'] as List? ?? const []);
      final rows = List<dynamic>.from(block['rows'] as List? ?? const []);
      if (headers.isEmpty) return const SizedBox.shrink();
      return Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: headers.map((h) => DataColumn(label: Text(h.toString()))).toList(),
          rows: rows.map((row) {
            final cells = List<dynamic>.from(row as List);
            return DataRow(cells: List<DataCell>.generate(headers.length,
              (i) => DataCell(Text(i < cells.length ? cells[i].toString() : ''))));
          }).toList(),
        )));
    }
    if (type == 'divider') return const Divider(height: 28);
    if (type == 'note') {
      final variant = (block['variant'] ?? 'info').toString();
      final color = variant == 'warning' ? Colors.orange : variant == 'tip' ? Colors.green : accent;
      return Card(color: color.withValues(alpha: .12), child: Padding(padding: const EdgeInsets.all(14), child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(variant == 'warning' ? Icons.warning_amber_rounded : variant == 'tip' ? Icons.lightbulb_outline_rounded : Icons.info_outline_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((block['title'] ?? '').toString().isNotEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(block['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(text),
          ])),
        ],
      )));
    }
    if (type == 'paragraph' || text.isNotEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 7),
        child: SelectableText(text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)));
    }
    return const SizedBox.shrink();
  }
}

class _LessonListItem extends StatelessWidget {
  const _LessonListItem({required this.item});
  final dynamic item;
  @override
  Widget build(BuildContext context) {
    if (item is! Map) return Text(item.toString(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45));
    final map = Map<String, dynamic>.from(item as Map);
    final children = List<dynamic>.from(map['children'] as List? ?? const []);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text((map['text'] ?? '').toString(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
      for (final child in children)
        Padding(padding: const EdgeInsets.only(left: 12, top: 4),
          child: Text('• ${child.toString()}', style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4))),
    ]);
  }
}

class InterviewNativeScreen extends StatefulWidget {
  const InterviewNativeScreen({super.key});
  @override State<InterviewNativeScreen> createState() => _InterviewNativeScreenState();
}
class _InterviewNativeScreenState extends State<InterviewNativeScreen> {
  SupabaseClient? client;
  bool busy = false;
  String? error;
  Map<String,dynamic>? profile;
  List<Map<String,dynamic>> questions = [];

  @override
  void initState() {
    super.initState();
    if (_interviewUrl.isNotEmpty && _interviewKey.isNotEmpty) {
      client = SupabaseClient(_interviewUrl, _interviewKey);
      _restoreInterviewSession();
    } else {
      error = 'Interview database configuration is missing.';
    }
  }

  Future<void> _restoreInterviewSession() async {
    if (client == null || !mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      setState(() {
        error = 'Your ControlDeck session has expired. Sign in to ControlDeck again.';
        busy = false;
      });
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final result = await Supabase.instance.client.functions.invoke(
        'controldeck-sso',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        body: {'app': 'interview', 'page': '/'},
      );
      final data = Map<String, dynamic>.from(result.data as Map);
      if (result.status >= 400 || data['error'] != null || data['ok'] != true) {
        throw Exception((data['error'] ?? 'Interview shared sign-in failed.').toString());
      }
      final linkedProfile = Map<String, dynamic>.from(data['profile'] as Map);
      if (mounted) setState(() { profile = linkedProfile; busy = false; });
      await loadQuestions();
    } catch (e) {
      if (mounted) setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        busy = false;
      });
    }
  }

  Future<void> loadQuestions() async {
    if (client == null) return;
    try {
      final rows = await client!.schema('interview').from('questions')
          .select('id,assessment_type,question_text,option_a,option_b,option_c,option_d,marks')
          .order('sort_order');
      if (mounted) setState(() => questions = List<Map<String,dynamic>>.from(rows));
    } catch (e) {
      if (mounted) setState(() => error = 'Signed in, but questions could not load: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)),
      title: const Text('Interview'),
    ),
    body: client == null
        ? _ConnectionNotice(title: 'Interview workspace unavailable', detail: error ?? 'The Interview data connection is not configured.')
        : profile == null
            ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 960), child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const _WorkspaceHero(title: 'Interview Dashboard', subtitle: 'Your ControlDeck session is used automatically. No separate Interview login is required.', icon: Icons.quiz_rounded),
                  const SizedBox(height: 18),
                  if (busy)
                    const Card(child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Row(children: [
                        SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                        SizedBox(width: 16),
                        Expanded(child: Text('Opening your Interview dashboard and loading your account…')),
                      ]),
                    ))
                  else if (error != null)
                    Card(child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Dashboard connection needs attention', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _restoreInterviewSession,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reload dashboard'),
                        ),
                      ]),
                    ))
                  else
                    const Card(child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Preparing your Interview dashboard…'),
                    )),
                ],
              )))
            : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 960), child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _WorkspaceHero(title: 'Welcome, ${profile!['name'] ?? 'User'}', subtitle: 'ControlDeck session active · ${profile!['usertype'] ?? 'user'} account', icon: Icons.account_circle_rounded),
                  const SizedBox(height: 18),
                  _DataSection(title: 'Available assessment questions', rows: questions.map((q) => {'question':q['question_text'],'type':q['assessment_type'],'marks':q['marks']}).toList()),
                  if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to ControlDeck'),
                  ),
                ],
              ))),
  );
}

class LifeHubNativeScreen extends StatefulWidget {
  const LifeHubNativeScreen({super.key});
  @override State<LifeHubNativeScreen> createState() => _LifeHubNativeScreenState();
}
class _LifeHubNativeScreenState extends State<LifeHubNativeScreen> {
  SupabaseClient client = SupabaseClient(_lifeHubUrl, _lifeHubKey);
  final taskTitle = TextEditingController();
  bool busy = false;
  String? error;
  Map<String,dynamic>? profile;
  String? sessionId;
  List<Map<String,dynamic>> tasks = [];

  @override void initState() { super.initState(); _restoreSession(); }
  @override void dispose() { taskTitle.dispose(); super.dispose(); }

  Future<void> _restoreSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (mounted) setState(() { error = 'Sign in to ControlDeck first, then reopen LifeHub.'; busy = false; });
      return;
    }
    if (mounted) setState(() { busy = true; error = null; });
    try {
      final result = await Supabase.instance.client.functions.invoke(
        'controldeck-sso',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        body: {'app': 'lifehub', 'page': '/'},
      );
      final data = Map<String, dynamic>.from(result.data as Map);
      if (result.status >= 400 || data['error'] != null) {
        throw Exception((data['error'] ?? 'Shared sign-in failed.').toString());
      }
      sessionId = data['sessionId']?.toString();
      profile = Map<String, dynamic>.from(data['profile'] as Map);
      if (sessionId == null || sessionId!.isEmpty) throw Exception('LifeHub did not return a valid session.');
      // Use the active API key for the LifeHub project itself. The build-time
      // ControlDeck key may belong to another Supabase project.
      final lifeHubApiKey = _lifeHubKey;
      client = SupabaseClient(_lifeHubUrl, lifeHubApiKey, headers: {'x-lifehub-session': sessionId!});
      await _secureStorage.write(key: _lifeHubSessionStorageKey, value: jsonEncode({
        'sessionId': sessionId, 'profile': profile, 'expiresAt': data['expiresAt'],
      }));
      if (mounted) setState(() { busy = false; });
      await loadTasks();
    } catch (e) {
      await _secureStorage.delete(key: _lifeHubSessionStorageKey);
      if (mounted) setState(() {
        profile = null; sessionId = null; tasks = [];
        error = e.toString().replaceFirst('Exception: ', '');
        busy = false;
      });
    }
  }

  Future<void> loadTasks() async {
    if (profile == null) return;
    if (mounted) setState(() { busy = true; error = null; });
    try {
      final rows = await client.from('tasks').select('*').eq('user_id', profile!['id']).order('created_at', ascending: false);
      if (mounted) setState(() { tasks = List<Map<String,dynamic>>.from(rows); busy = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); busy = false; });
    }
  }

  Future<void> toggleTask(Map<String, dynamic> task, bool done) async {
    if (profile == null) return;
    setState(() { busy = true; error = null; });
    try {
      await client.from('tasks').update({'status': done ? 'done' : 'pending'})
        .eq('id', task['id']).eq('user_id', profile!['id']);
      await loadTasks();
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); busy = false; });
    }
  }

  Future<void> deleteTask(Map<String, dynamic> task) async {
    if (profile == null) return;
    setState(() { busy = true; error = null; });
    try {
      await client.from('tasks').delete().eq('id', task['id']).eq('user_id', profile!['id']);
      await loadTasks();
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); busy = false; });
    }
  }

  Future<void> addTask() async {
    if (taskTitle.text.trim().isEmpty || profile == null) return;
    setState(() { busy = true; error = null; });
    try {
      await client.from('tasks').insert({'user_id': profile!['id'], 'title': taskTitle.text.trim(), 'priority': 'medium', 'status': 'pending'});
      taskTitle.clear();
      await loadTasks();
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); busy = false; });
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('LifeHub')),
    body: profile == null
      ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(22), children: [
          const _WorkspaceHero(title: 'LifeHub', subtitle: 'Uses your ControlDeck sign-in automatically.', icon: Icons.home_work_rounded),
          if (busy) const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: busy ? null : _restoreSession, icon: const Icon(Icons.refresh_rounded), label: const Text('Try shared sign-in again')),
          TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Back to ControlDeck')),
        ])))
      : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 980), child: ListView(padding: const EdgeInsets.all(20), children: [
          _WorkspaceHero(title: 'Welcome, ${profile!['full_name'] ?? profile!['name'] ?? 'there'}', subtitle: 'LifeHub · Tasks and personal planning', icon: Icons.home_work_rounded),
          const SizedBox(height: 18),
          Row(children: [Expanded(child: TextField(controller: taskTitle, onSubmitted: (_) => addTask(), decoration: const InputDecoration(labelText: 'Add a task', prefixIcon: Icon(Icons.add_task_rounded)))), const SizedBox(width: 10), FilledButton(onPressed: busy ? null : addTask, child: const Text('Add'))]),
          const SizedBox(height: 14),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tasks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (tasks.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Text('No tasks yet. Add your first task above.')),
            for (final task in tasks)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: task['status'] == 'done',
                onChanged: busy ? null : (value) => toggleTask(task, value ?? false),
                title: Text((task['title'] ?? 'Untitled task').toString(), style: TextStyle(decoration: task['status'] == 'done' ? TextDecoration.lineThrough : null)),
                subtitle: Text([
                  if ((task['priority'] ?? '').toString().isNotEmpty) 'Priority: ${task['priority']}',
                  if ((task['due_date'] ?? '').toString().isNotEmpty) 'Due: ${task['due_date']}',
                  task['status'] == 'done' ? 'Completed' : 'Pending',
                ].join(' · ')),
                secondary: IconButton(tooltip: 'Delete task', onPressed: busy ? null : () => deleteTask(task), icon: const Icon(Icons.delete_outline_rounded)),
              ),
          ]))),
          if (busy) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
          if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          OutlinedButton.icon(onPressed: signOutControlDeck, icon: const Icon(Icons.logout_rounded), label: const Text('Sign out of ControlDeck')),
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
      Text((row.values.isNotEmpty ? row.values.first : 'Item').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
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
        _NavItem(icon: Icons.apps_rounded, label: 'All apps', selected: page == 'All apps', onTap: () => onSelect('All apps')),
        _NavItem(icon: Icons.account_circle_outlined, label: 'Profile', selected: page == 'Profile', onTap: () => onSelect('Profile')),
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

class _AppCard extends StatelessWidget {
  const _AppCard({required this.app, required this.onOpen});
  final DeckApp app;
  final VoidCallback onOpen;
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context); final tint = Color(app.accentHex);
    return Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: onOpen, child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: tint.withValues(alpha: .15), borderRadius: BorderRadius.circular(13)), child: IconTheme(data: IconThemeData(color: tint, size: 23), child: iconFor(app.iconKey))),
        ]),
        const SizedBox(height: 8), Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
                Text(app.description.isEmpty ? 'Open this workspace inside ControlDeck.' : app.description,
          maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.3)),
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
  const _EmptyState();
  @override Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(30),
    child: Column(children: [
      Icon(Icons.widgets_outlined, size: 42),
      SizedBox(height: 12),
      Text('Nothing here yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      SizedBox(height: 6),
      Text('No apps are available to display.'),
    ]),
  );
}
