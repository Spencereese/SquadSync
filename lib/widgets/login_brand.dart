import 'package:flutter/material.dart';

/// Peacock mark + title. Always shown — no phone-only breakpoint.
class LoginBrandHeader extends StatelessWidget {
  const LoginBrandHeader({
    super.key,
    required this.neon,
    this.titleColor = const Color(0xFFF5FBFF),
    this.subtitleColor = const Color(0xFFD6E8F5),
  });

  static const logoAsset = 'assets/images/logo.png';
  static const logoKey = Key('login-peacock-logo');

  final Color neon;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Image.asset(
            logoAsset,
            key: logoKey,
            width: 96,
            height: 96,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => Icon(
              Icons.groups_3_rounded,
              size: 72,
              color: neon,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Cod Squad',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to find your squad',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: subtitleColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Full-width "Forgot password?" — never a shrink-wrapped chip that ellipsizes.
class ForgotPasswordButton extends StatelessWidget {
  const ForgotPasswordButton({
    super.key,
    required this.onPressed,
    this.color,
  });

  static const label = 'Forgot password?';

  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = color ?? theme.colorScheme.primary;
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          minimumSize: const Size.fromHeight(44),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
        ),
        child: Text(
          label,
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.clip,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            color: labelColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }
}
