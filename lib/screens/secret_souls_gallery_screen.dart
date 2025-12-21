import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';
import '../services/database_service.dart';

class SecretSoulsGalleryScreen extends StatefulWidget {
  const SecretSoulsGalleryScreen({super.key});

  @override
  State<SecretSoulsGalleryScreen> createState() => _SecretSoulsGalleryScreenState();
}

class _SecretSoulsGalleryScreenState extends State<SecretSoulsGalleryScreen> {
  final DatabaseService _db = DatabaseService();
  final ScrollController _controller = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 0;
  bool _loading = false;
  bool _end = false;

  @override
  void initState() {
    super.initState();
    _load();
    _controller.addListener(() {
      if (_controller.position.pixels >= _controller.position.maxScrollExtent - 200 && !_loading && !_end) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final next = await _db.getSecretSoulsPhotos(page: _page);
    setState(() {
      if (next.isEmpty && _page == 0) {
        _items.addAll([
          {'asset': 'assets/images/avatar_1.jpeg'},
          {'asset': 'assets/images/letter.png'},
          {'asset': 'assets/images/avatar_1.jpeg'},
          {'asset': 'assets/images/letter.png'},
          {'asset': 'assets/images/avatar_1.jpeg'},
          {'asset': 'assets/images/letter.png'},
        ]);
      } else {
        _items.addAll(next);
      }
      _page++;
      _loading = false;
      if (next.isEmpty) _end = true;
    });
    // Prefetch newly loaded thumbnails
    for (final it in next) {
      final url = it['url'] as String?;
      if (url != null && mounted) {
        precacheImage(NetworkImage(url), context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr.tr('secret_souls.title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(tr.tr('secret_souls.no_contact')),
          ),
          Expanded(
            child: GridView.builder(
              controller: _controller,
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: (_page == 0 && _loading)
                  ? 9
                  : _items.length + (_loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_page == 0 && _loading) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }
                if (index >= _items.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                final it = _items[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: it.containsKey('asset')
                      ? Image.asset(it['asset'] as String, fit: BoxFit.cover)
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: const Color(0xFFEFEFEF)),
                            Image.network(it['url'] as String, fit: BoxFit.cover),
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
