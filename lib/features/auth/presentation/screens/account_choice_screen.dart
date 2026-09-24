import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/constants/app_typography.dart';
import 'package:fast_flow/shared/widgets/app_button.dart';

class AccountChoiceScreen extends StatelessWidget {
  const AccountChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // App Logo / Icon Header
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.spa_rounded,
                    size: 56,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xlg),
              Text(
                'Welcome to Fomo IF',
                textAlign: TextAlign.center,
                style: AppTypography.headlineLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Track your fasting windows, manage routines, and monitor your wellness offline or synced with your account.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const Spacer(flex: 3),

              // Option A: "I already have an account"
              AppButton.primary(
                key: const Key('account_choice_login_btn'),
                label: 'I already have an account',
                isFullWidth: true,
                size: AppButtonSize.lg,
                icon: Icons.login_rounded,
                onPressed: () {
                  context.push('/login');
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Option B: "Continue without an account"
              AppButton.outlined(
                key: const Key('account_choice_guest_btn'),
                label: 'Continue without an account',
                isFullWidth: true,
                size: AppButtonSize.lg,
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  context.go('/onboarding');
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Alternative: Create Account
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New to Fomo IF? ',
                    style: AppTypography.bodySmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    key: const Key('account_choice_register_btn'),
                    onPressed: () {
                      context.push('/register');
                    },
                    child: const Text('Create Account'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}
