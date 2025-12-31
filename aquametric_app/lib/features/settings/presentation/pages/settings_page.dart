import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'プロフィール',
            children: [
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'アカウント',
                subtitle: 'swimmer@example.com',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.pool_outlined,
                title: 'デフォルトプール長',
                subtitle: '25m',
                onTap: () => _showPoolLengthDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '通知',
            children: [
              _SettingsToggle(
                icon: Icons.notifications_outlined,
                title: 'プッシュ通知',
                subtitle: 'セッション完了時に通知',
                value: true,
                onChanged: (value) {},
              ),
              _SettingsToggle(
                icon: Icons.sync,
                title: '自動同期',
                subtitle: 'Wi-Fi接続時に自動同期',
                value: true,
                onChanged: (value) {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'データ',
            children: [
              _SettingsTile(
                icon: Icons.cloud_download_outlined,
                title: 'データのエクスポート',
                subtitle: 'CSV形式でダウンロード',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.delete_outline,
                title: 'キャッシュをクリア',
                subtitle: '一時データを削除',
                onTap: () => _showClearCacheDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'サポート',
            children: [
              _SettingsTile(
                icon: Icons.help_outline,
                title: 'ヘルプ',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.feedback_outlined,
                title: 'フィードバック',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'バージョン情報',
                subtitle: 'v1.0.0',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: TextButton(
              onPressed: () => _showLogoutDialog(context),
              child: const Text(
                'ログアウト',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  void _showPoolLengthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('デフォルトプール長'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                title: const Text('25m'),
                value: 25,
                groupValue: 25,
                onChanged: (value) {
                  Navigator.pop(context);
                },
              ),
              RadioListTile<int>(
                title: const Text('50m'),
                value: 50,
                groupValue: 25,
                onChanged: (value) {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
          ],
        );
      },
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('キャッシュをクリア'),
          content: const Text('一時データを削除しますか？この操作は取り消せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('キャッシュをクリアしました')),
                );
              },
              child: const Text('クリア', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ログアウト'),
          content: const Text('本当にログアウトしますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('ログアウト', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
    );
  }
}
