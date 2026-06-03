import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ConnectionCard extends StatelessWidget {
  final String name;
  final String endpoint;
  final bool connected;

  const ConnectionCard({
    super.key,
    required this.name,
    required this.endpoint,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderDark),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // LED indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? kSuccess : kDanger,
                  boxShadow: connected
                      ? [BoxShadow(color: kSuccess.withOpacity(0.4), blurRadius: 6, spreadRadius: 1)]
                      : [],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: connected
                      ? kSuccess.withOpacity(0.15)
                      : kDanger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: connected ? kSuccess : kDanger,
                    width: 1,
                  ),
                ),
                child: Text(
                  connected ? 'CONNECTED' : 'DISCONNECTED',
                  style: TextStyle(
                    color: connected ? kSuccess : kDanger,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            endpoint,
            style: const TextStyle(
              color: kTextSub,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
