import 'package:flutter/material.dart';
import '../models/two_factor_item.dart';

class AccountTile extends StatelessWidget {
  final TwoFactorItem item;

  const AccountTile({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    final color = Colors.primaries[item.service.length % Colors.primaries.length];
    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 24,
            backgroundColor: color.shade100,
            child: Text(item.service.characters.first, style: TextStyle(color: color.shade900, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.service, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(item.account, style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(item.twoFa, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.nextTwoFa, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(width: 8),
                    Row(
                      children: List.generate(10, (i) {
                        final Color dotColor = i < 6
                            ? Colors.green.shade400
                            : (i < 9 ? Colors.amber.shade600 : Colors.red.shade400);
                        return Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1.0),
                          decoration: BoxDecoration(
                            color: dotColor,
                            borderRadius: BorderRadius.circular(2.0),
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
