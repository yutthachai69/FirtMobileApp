import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/auth/auth_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.auth});
  final AuthController auth;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) {
      final account = auth.account;
      if (account == null) return const SizedBox.shrink();
      return Scaffold(
        appBar: AppBar(title: const Text('RelayContent')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'สวัสดี${account.name.isEmpty ? '' : ', ${account.name}'}',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ยินดีต้อนรับสู่พื้นที่ทำงานของคุณ',
                      style: TextStyle(color: context.t.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.t.surfaceContainer,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.t.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.account_circle_outlined,
                            color: context.t.primary,
                            size: 44,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'บัญชีของคุณ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'อีเมล',
                            style: TextStyle(color: context.t.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(account.email),
                          const SizedBox(height: 20),
                          Text(
                            'เขตเวลา',
                            style: TextStyle(color: context.t.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(account.timezone),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: context.t.success,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'เข้าสู่ระบบแล้ว\nเปิดแอปครั้งถัดไปเพื่อทำงานต่อด้วยบัญชีนี้',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (auth.error != null)
                      Text(
                        auth.error!,
                        style: TextStyle(color: context.t.error),
                      ),
                    FilledButton.icon(
                      onPressed: () => context.push('/connections'),
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('เชื่อมต่อบัญชี'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: auth.busy ? null : auth.signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(
                        auth.busy ? 'กำลังออกจากระบบ…' : 'ออกจากระบบ',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
