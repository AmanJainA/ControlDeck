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
