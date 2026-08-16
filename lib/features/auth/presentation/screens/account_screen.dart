import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/core/services/auth_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/user_data_migration_service.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/app_dialog.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value ?? AuthService.instance.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final deviceId = FcmService.instance.getOrCreateDeviceId();
    final hasLocalData = HiveService.instance.hasUnclaimedLocalUserData() ||
        (HiveService.instance.userProfile != null && user == null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.md,
        ),
        children: [
          if (user == null) ...[
            // ── STATE A: NO AUTHENTICATED ACCOUNT ──
            AppCard.elevated(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No account connected',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Local data is available on this device.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (hasLocalData) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.storage_rounded,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Existing local data found',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    'Your fasting history and settings can be linked to your new account.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context.push('/register'),
                            child: const Text('Create Account'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.push('/login'),
                            child: const Text('Log In'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // ── STATE B: USER IS LOGGED IN ──
            AppCard.elevated(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        (user.displayName?.isNotEmpty == true
                                ? user.displayName![0]
                                : (user.email?.isNotEmpty == true
                                    ? user.email![0]
                                    : 'U'))
                            .toUpperCase(),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      user.displayName?.isNotEmpty == true
                          ? user.displayName!
                          : (HiveService.instance.userProfile?.name.isNotEmpty == true
                              ? HiveService.instance.userProfile!.name
                              : 'Account User'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user.email != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        user.email!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Linked Device: $deviceId',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () => _showSwitchAccountSheet(context),
                              icon: const Icon(Icons.switch_account_rounded),
                              label: const Text('Switch Account'),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () => _handleLogout(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.error,
                                side: BorderSide(color: colorScheme.error),
                              ),
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Log Out'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await AppDialog.showConfirm(
      context: context,
      title: 'Log out?',
      content: 'Your local data will remain on this device. Logging out will not delete your data.',
      confirmLabel: 'LOG OUT',
      cancelLabel: 'CANCEL',
      isDestructive: true,
    );

    if (confirm == true) {
      await AuthService.instance.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully.')),
        );
      }
    }
  }

  void _showSwitchAccountSheet(BuildContext context) {
    final accounts = HiveService.instance.knownAccounts;
    final currentUid = AuthService.instance.currentUser?.uid ?? UserDataMigrationService.instance.boundFirebaseUid;


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Switch Account',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(),
                if (accounts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(
                      'No other authenticated accounts found on this device.',
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  )
                else
                  ...accounts.map((acc) {
                    final uid = acc['uid'] ?? '';
                    final email = acc['email'] ?? 'Account';
                    final name = acc['displayName'] ?? email.split('@').first;
                    final isSelected = uid == currentUid;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(name[0].toUpperCase()),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(email),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: Theme.of(ctx).colorScheme.primary)
                          : const Icon(Icons.radio_button_unchecked_rounded),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        if (!isSelected && uid.isNotEmpty) {
                          await UserDataMigrationService.instance.switchAccount(uid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Switched to account $email')),
                            );
                            context.go('/home');
                          }
                        }
                      },
                    );
                  }),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.push('/login');
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add another account'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
