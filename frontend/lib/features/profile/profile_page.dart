import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_models.dart';
import '../../core/api/providers.dart';
import '../../core/storage/local_preferences.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadProfile);
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authTokenProvider);
    if (token == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MindVaultColors.surface,
      body: Row(
        children: [
          _AccountSidebar(
            profile: _profile,
            onBack: () => context.go('/'),
            onSignOut: () {
              ref.read(authTokenProvider.notifier).state = null;
              LocalPreferences.saveAuthToken(null);
              context.go('/login');
            },
          ),
          Expanded(
            child: Container(
              color: MindVaultColors.surface,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _ProfileContent(
                      profile: _profile,
                      saving: _saving,
                      error: _error,
                      onRetry: _loadProfile,
                      onEditUsername: _editUsername,
                      onEditEmail: _editEmail,
                      onEditAvatar: _editAvatar,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ref.read(authRepositoryProvider).me();
      if (mounted) {
        setState(() => _profile = profile);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load account profile.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _editUsername() async {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    final value = await _showEditDialog(title: 'Edit username', label: 'Username', initialValue: profile.username);
    if (value == null || value.trim().isEmpty) {
      return;
    }
    await _saveProfile(username: value.trim(), email: profile.email, avatar: profile.avatar);
  }

  Future<void> _editEmail() async {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    final value = await _showEditDialog(
      title: 'Bind email',
      label: 'Email',
      initialValue: profile.email,
      keyboardType: TextInputType.emailAddress,
    );
    if (value == null || value.trim().isEmpty) {
      return;
    }
    await _saveProfile(username: profile.username, email: value.trim(), avatar: profile.avatar);
  }

  Future<void> _editAvatar() async {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    final value = await _showEditDialog(
      title: 'Edit avatar',
      label: 'Avatar URL',
      initialValue: profile.avatar ?? '',
      keyboardType: TextInputType.url,
    );
    if (value == null) {
      return;
    }
    await _saveProfile(username: profile.username, email: profile.email, avatar: value.trim());
  }

  Future<String?> _showEditDialog({
    required String title,
    required String label,
    required String initialValue,
    TextInputType? keyboardType,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _saveProfile({required String username, required String email, String? avatar}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = await ref.read(authRepositoryProvider).updateProfile(
            username: username,
            email: email,
            avatar: avatar,
          );
      if (!mounted) {
        return;
      }
      setState(() => _profile = profile);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to save profile. Check whether the email is already used.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _AccountSidebar extends StatelessWidget {
  const _AccountSidebar({
    required this.profile,
    required this.onBack,
    required this.onSignOut,
  });

  final UserProfile? profile;
  final VoidCallback onBack;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: MindVaultColors.surface,
        border: Border(right: BorderSide(color: MindVaultColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new, size: 16),
              label: const Text('Back'),
              style: TextButton.styleFrom(foregroundColor: MindVaultColors.text),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _Avatar(profile: profile, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.username ?? 'MindVault User',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile == null ? 'Loading profile' : 'u${profile!.id}',
                        style: const TextStyle(fontSize: 13, color: MindVaultColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _SidebarSectionTitle('Account'),
          const _SidebarItem(icon: Icons.person_outline, label: 'Personal info'),
          const _SidebarItem(icon: Icons.tune_outlined, label: 'Preferences'),
          const _SidebarItem(icon: Icons.security_outlined, label: 'Security log'),
          const _SidebarItem(icon: Icons.manage_accounts_outlined, label: 'Account management', selected: true),
          const SizedBox(height: 24),
          const _SidebarSectionTitle('Workspace'),
          const _SidebarItem(icon: Icons.query_stats_outlined, label: 'Knowledge stats'),
          const _SidebarItem(icon: Icons.hub_outlined, label: 'Graph settings'),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign out'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.saving,
    required this.error,
    required this.onRetry,
    required this.onEditUsername,
    required this.onEditEmail,
    required this.onEditAvatar,
  });

  final UserProfile? profile;
  final bool saving;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onEditUsername;
  final VoidCallback onEditEmail;
  final VoidCallback onEditAvatar;

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error ?? 'Account profile is unavailable.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    final hasEmail = profile!.email.trim().isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(84, 36, 48, 56),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Account management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (saving) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 34),
            const Text('Account binding', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.info, color: MindVaultColors.warning, size: 18),
                const SizedBox(width: 8),
                Text(
                  hasEmail ? 'Your account has an email bound for sign-in and recovery.' : 'Bind an email to improve account security.',
                  style: const TextStyle(color: MindVaultColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _BindingCard(
              icon: Icons.person_outline,
              status: _BindingStatus.good,
              title: 'Username',
              subtitle: profile!.username,
              action: 'Change',
              onPressed: onEditUsername,
            ),
            _BindingCard(
              icon: Icons.mail_outline,
              status: hasEmail ? _BindingStatus.good : _BindingStatus.warning,
              title: 'Email',
              subtitle: hasEmail ? profile!.email : 'Not bound. Email is used for account recovery.',
              action: hasEmail ? 'Change' : 'Bind',
              onPressed: onEditEmail,
            ),
            _BindingCard(
              icon: Icons.image_outlined,
              status: profile!.avatar == null ? _BindingStatus.warning : _BindingStatus.good,
              title: 'Avatar',
              subtitle: profile!.avatar == null ? 'No custom avatar URL.' : profile!.avatar!,
              action: profile!.avatar == null ? 'Add' : 'Change',
              onPressed: onEditAvatar,
            ),
            _BindingCard(
              icon: Icons.lock_outline,
              status: _BindingStatus.good,
              title: 'Password',
              subtitle: 'Set. You can sign in with your account password.',
              action: 'Change',
              onPressed: () {},
            ),
            _BindingCard(
              icon: Icons.link_outlined,
              status: _BindingStatus.good,
              title: 'Personal path',
              subtitle: 'mindvault.local/u${profile!.id}',
              action: 'Change',
              onPressed: onEditUsername,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: MindVaultColors.error)),
            ],
            const SizedBox(height: 42),
            const Text('Third-party accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Quick sign-in channels are placeholders for future releases.',
              style: TextStyle(color: MindVaultColors.muted),
            ),
            const SizedBox(height: 18),
            const Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ThirdPartyCard(name: 'DingTalk', color: Color(0xFF1677FF)),
                _ThirdPartyCard(name: 'Alipay', color: Color(0xFF1677FF)),
                _ThirdPartyCard(name: 'WeChat', color: Color(0xFF22C55E)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _BindingStatus { good, warning }

class _BindingCard extends StatelessWidget {
  const _BindingCard({
    required this.icon,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onPressed,
  });

  final IconData icon;
  final _BindingStatus status;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final statusColor = status == _BindingStatus.good ? MindVaultColors.success : MindVaultColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF2F3F5)),
      ),
      child: Row(
        children: [
          Icon(status == _BindingStatus.good ? Icons.check : Icons.priority_high, color: statusColor, size: 28),
          const SizedBox(width: 22),
          Icon(icon, color: MindVaultColors.muted, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: MindVaultColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    );
  }
}

class _ThirdPartyCard extends StatelessWidget {
  const _ThirdPartyCard({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF2F3F5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: const Icon(Icons.bolt, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),
          const TextButton(onPressed: null, child: Text('Bind')),
        ],
      ),
    );
  }
}

class _SidebarSectionTitle extends StatelessWidget {
  const _SidebarSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Text(label, style: const TextStyle(fontSize: 14, color: MindVaultColors.muted)),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.icon, required this.label, this.selected = false});

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? MindVaultColors.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: selected ? MindVaultColors.text : MindVaultColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? MindVaultColors.text : MindVaultColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.size});

  final UserProfile? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatar = profile?.avatar;
    if (avatar != null && avatar.isNotEmpty) {
      return CircleAvatar(radius: size / 2, backgroundImage: NetworkImage(avatar));
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFE5E7EB),
      child: Icon(Icons.person, color: Colors.white, size: size * 0.55),
    );
  }
}
