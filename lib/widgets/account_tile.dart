import 'package:flutter/material.dart';
import '../models/two_factor_item.dart';

class AccountTile extends StatelessWidget {
  final TwoFactorItem item;

  const AccountTile({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    final color = Colors.primaries[item.service.length % Colors.primaries.length];
  // debugBoxes removed; restoring production layout
    return SizedBox(
      height: 70,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 12),
          // Service and account column with new layout
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First row: Avatar and Service
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1.0),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: color.shade100,
                          child: Text(
                            item.service.characters.first, 
                            style: TextStyle(
                              color: color.shade900, 
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            )
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.service, 
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400)
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Second row: Account
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0), // Align with service text
                    child: Text(
                      item.account, 
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600)
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Small code column (left of main code) - bottom-right aligned
          SizedBox(
            width: 54,
            height: 60,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Text(item.nextTwoFa, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ),
          ),

          const SizedBox(width: 8),

          // Main code column (right)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 100, maxWidth: 110),
            child: Container(
              padding: const EdgeInsets.only(right: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(item.twoFa, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(10, (i) {
                        final Color dotColor = i < 6
                            ? Colors.green.shade400
                            : (i < 9 ? Colors.amber.shade600 : Colors.red.shade400);
                        return Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 6.0),
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: dotColor,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
