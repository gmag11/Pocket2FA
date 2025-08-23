import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _SearchBar(),
            ),
            const SizedBox(height: 12),
            Expanded(child: _AccountList()),
            const _BottomBar(),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Search',
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountList extends StatelessWidget {
    final List<Map<String, String>> items = const [
  {'title': 'Amazon', 'subtitle': 'user+amazon@example.com', 'code': '110 254', 'small': '165 719'},
  {'title': 'Anydesk', 'subtitle': 'device-iPhone-15', 'code': '630 542', 'small': '492 255'},
  {'title': 'Atlassian', 'subtitle': 'user+atlassian@example.com', 'code': '049 996', 'small': '531 958'},
  {'title': 'Authelia', 'subtitle': 'user_authelia', 'code': '857 740', 'small': '108 089'},
  {'title': 'Authentik', 'subtitle': 'admin', 'code': '695 269', 'small': '346 987'},
  {'title': 'Authentik', 'subtitle': 'user_auth', 'code': '929 141', 'small': '416 287'},
  {'title': 'Autodesk', 'subtitle': 'user+autodesk@example.com', 'code': '921 253', 'small': '239 551'},
  {'title': 'AWS SSO', 'subtitle': 'user_aws', 'code': '560 595', 'small': '091 891'},
  {'title': 'BingX', 'subtitle': 'user+bingx@example.com', 'code': '540 784', 'small': '485 662'},
  {'title': 'GitHost', 'subtitle': 'devops', 'code': '541 678', 'small': '123 456'},
  {'title': 'Dropbox', 'subtitle': 'user+dropbox@example.com', 'code': '312 450', 'small': '654 321'},
  {'title': 'Google', 'subtitle': 'user+google@example.com', 'code': '782 901', 'small': '888 777'},
  {'title': 'Microsoft', 'subtitle': 'user+microsoft@example.com', 'code': '450 120', 'small': '333 222'},
  {'title': 'Facebook', 'subtitle': 'user+facebook@example.com', 'code': '223 334', 'small': '101 202'},
  {'title': 'Twitter', 'subtitle': 'user+twitter@example.com', 'code': '998 001', 'small': '909 808'},
  {'title': 'CustomApp', 'subtitle': 'service_account', 'code': '010 203', 'small': '010 011'},
  ];

  const _AccountList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemBuilder: (context, index) {
        final item = items[index % items.length];
        return _AccountTile(
          title: item['title']!,
          subtitle: item['subtitle']!,
          code: item['code']!,
          small: item['small'] ?? '',
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, endIndent: 12),
      itemCount: items.length,
    );
  }
}

class _AccountTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String code;
  final String small;

  const _AccountTile({required this.title, required this.subtitle, required this.code, required this.small});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 12),
          _IconCircle(label: title),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(code, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(small, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(width: 8),
                    Row(
                      children: List.generate(10, (i) {
                        final Color dotColor = i < 6
                            ? Colors.green.shade400
                            : (i < 9 ? Colors.amber.shade600 : Colors.red.shade400);
                        return Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: dotColor,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  final String label;
  const _IconCircle({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Colors.primaries[label.length % Colors.primaries.length];
    return CircleAvatar(
      radius: 28,
      backgroundColor: color.shade100,
      child: Text(label.characters.first, style: TextStyle(color: color.shade900, fontWeight: FontWeight.bold)),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: Colors.indigo,
                ),
                label: const Text('New'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.person_outline, size: 18, color: Colors.grey),
              SizedBox(width: 8),
              Text('gmartin@gmartin.net', style: TextStyle(color: Colors.grey)),
              SizedBox(width: 6),
              Icon(Icons.more_vert, size: 18, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }
}
