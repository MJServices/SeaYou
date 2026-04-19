import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';
import '../services/database_service.dart';
import '../services/entitlements_service.dart';
import '../services/auth_service.dart';
import 'premium_screen.dart';
import 'purchase_scrolls_screen.dart';

class ChamberOfSecretsScreen extends StatefulWidget {
  const ChamberOfSecretsScreen({super.key});

  @override
  State<ChamberOfSecretsScreen> createState() => _ChamberOfSecretsScreenState();
}

class _ChamberOfSecretsScreenState extends State<ChamberOfSecretsScreen> {
  final DatabaseService _db = DatabaseService();
  final ScrollController _controller = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 0;
  bool _loading = false;
  bool _end = false;
  String _tier = 'free';

  @override
  void initState() {
    super.initState();
    _init();
    _controller.addListener(() {
      if (_controller.position.pixels >=
              _controller.position.maxScrollExtent - 200 &&
          !_loading &&
          !_end) {
        _load();
      }
    });
  }

  Future<void> _init() async {
    final user = AuthService().currentUser;
    if (user != null) {
      _tier = await EntitlementsService().getTier(user.id);
    } else {
      _tier = 'elite';
    }
    await _load();
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final next = await _db.listFantasies(page: _page);
    setState(() {
      if (next.isEmpty && _page == 0) {
        _items.addAll([
          {
            'id': 'demo_f1',
            'text': 'Under the moonlit sky, a whisper becomes a promise.',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'id': 'demo_f2',
            'text': 'Hands on the piano keys, hearts racing to the rhythm.',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'id': 'demo_f3',
            'text': 'A secret note tucked in a book at a quiet café.',
            'created_at': DateTime.now().toIso8601String(),
          },
        ]);
      } else {
        _items.addAll(next);
      }
      _page++;
      _loading = false;
      if (next.isEmpty) _end = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr.tr('chamber.title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(tr.tr('chamber.subtitle')),
          ),
          if (_tier == 'free')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE3E3E3)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(tr.tr('chamber.non_premium_bubble'))),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const PremiumScreen()),
                        );
                      },
                      child: Text(AppLocalizations.of(context)
                          .tr('premium.gate.subscribe')),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _controller,
              itemCount: _items.length + (_loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final it = _items[index];
                return ListTile(
                  title: Text(it['text'] as String),
                  subtitle: Text(it['created_at'] as String),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final user = AuthService().currentUser;
                          if (user != null) {
                            await _db.reportFantasy(
                              fantasyId: it['id'] as String,
                              reporterId: user.id,
                              reason: 'inappropriate',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Reported')),
                              );
                            }
                          }
                        },
                        child: Text(tr.tr('chamber.report')),
                      ),
                      if (_tier == 'elite')
                        TextButton(
                          onPressed: () async {
                            final user = AuthService().currentUser;
                            if (user == null) return;
                            final ownerId = it['user_id'] as String?;
                            final fantasyId = it['id'] as String?;
                            if (ownerId == null || fantasyId == null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Demo item cannot start DM')),
                                );
                              }
                              return;
                            }
                            final confirm = await showDialog<bool>(
                              context: context,
                              barrierColor: Colors.black.withValues(alpha: 0.2),
                              builder: (_) => AlertDialog(
                                title: Text(AppLocalizations.of(context)
                                    .tr('chamber.elite_dm')),
                                content: const Text(
                                    'Start anonymous elite conversation?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(AppLocalizations.of(context)
                                          .tr('dialogs.cancel'))),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Start')),
                                ],
                              ),
                            );
                            if (confirm != true) return;

                            // Special area: consume scroll (limit to 3 for Premium/Women via daily_free_scrolls)
                            final deducted = await _db.deductScroll(user.id);
                            if (!deducted) {
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    final tr = AppLocalizations.of(context);
                                    return Dialog(
                                      backgroundColor: const Color(0xFFFFF7E6),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.history_edu,
                                                size: 50,
                                                color: Color(0xFFD4B483)),
                                            const SizedBox(height: 16),
                                            Text(
                                              tr.tr('send_bottle.out_of_scrolls_title'),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontFamily: 'PlayfairDisplay',
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF3E2723),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              tr.tr('send_bottle.out_of_scrolls_message'),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 14,
                                                color: Color(0xFF5D4037),
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            ElevatedButton(
                                              onPressed: () async {
                                                Navigator.pop(context);
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          const PurchaseScrollsScreen()),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFFE4C687),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            24)),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 24,
                                                        vertical: 12),
                                              ),
                                              child: Text(tr.tr('premium_screen.purchase_scrolls')),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: Text(
                                                tr.tr('dialogs.cancel'),
                                                style: const TextStyle(
                                                    color: Color(0xFF5D4037)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }
                              return;
                            }

                            final convId =
                                await _db.startAnonymousFantasyConversation(
                              fantasyId: fantasyId,
                              requesterId: user.id,
                              ownerId: ownerId,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(convId != null
                                        ? AppLocalizations.of(context)
                                            .tr('messages.conversation_started')
                                        : AppLocalizations.of(context).tr(
                                            'messages.conversation_failed'))),
                              );
                            }
                          },
                          child: Text(tr.tr('chamber.elite_dm')),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
