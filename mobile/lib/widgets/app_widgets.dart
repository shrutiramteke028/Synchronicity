import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BrandMark(),
                  const Spacer(),
                  if (showBack)
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.deepLavender,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 30),
              Text(title, style: AppTypography.heading),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, style: AppTypography.body),
              ],
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 25,
          height: 25,
          decoration: const BoxDecoration(
            color: AppColors.primaryLavender,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.family_restroom, size: 16, color: AppColors.white),
        ),
        const SizedBox(width: 8),
        const Text(
          'SYNCHRONICITY',
          style: TextStyle(
            color: AppColors.deepLavender,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward, size: 19),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLavender,
          foregroundColor: AppColors.white,
          elevation: 4,
          shadowColor: AppColors.lightLavender,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepLavender,
          side: const BorderSide(color: AppColors.lightLavender),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color = AppColors.white,
    this.borderColor = AppColors.softGray,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color color;
  final Color borderColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A303040),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SoftIllustration extends StatelessWidget {
  const SoftIllustration({
    super.key,
    this.icon = Icons.people_alt_outlined,
  });

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 160,
        height: 118,
        decoration: BoxDecoration(
          color: AppColors.paleMauve.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 104,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: CustomPaint(
              painter: FamilyConnectionPainter(accent: AppColors.deepLavender),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class FamilyConnectionPainter extends CustomPainter {
  const FamilyConnectionPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final linePaint = Paint()
      ..color = AppColors.softPink
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final personPaint = Paint()..color = accent;
    final smallPaint = Paint()..color = AppColors.secondaryLavender;

    canvas.drawLine(
      Offset(center.dx - 28, center.dy + 4),
      Offset(center.dx + 28, center.dy + 4),
      linePaint,
    );
    for (final point in [
      Offset(center.dx - 28, center.dy - 13),
      Offset(center.dx, center.dy - 24),
      Offset(center.dx + 28, center.dy - 13),
    ]) {
      canvas.drawCircle(point, 8, personPaint);
    }
    canvas.drawCircle(Offset(center.dx - 28, center.dy + 12), 12, smallPaint);
    canvas.drawCircle(Offset(center.dx + 28, center.dy + 12), 12, smallPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + 17),
          width: 26,
          height: 20,
        ),
        const Radius.circular(10),
      ),
      personPaint,
    );
  }

  @override
  bool shouldRepaint(covariant FamilyConnectionPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 9),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.3,
          fontWeight: FontWeight.w700,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }
}

class MemberRow extends StatelessWidget {
  const MemberRow({
    super.key,
    required this.name,
    required this.time,
    required this.status,
    this.detail,
  });

  final String name;
  final String time;
  final String status;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: status == 'Busy'
            ? AppColors.softPink
            : AppColors.lightLavender,
        child: Text(
          name[0],
          style: const TextStyle(
            color: AppColors.deepLavender,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: AppTypography.label),
          if (detail != null)
            Text(
              detail!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
            ),
        ],
      ),
      subtitle: Text(
        time,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.secondaryText,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: status == 'Busy' || status == 'In a call'
                  ? AppColors.pink
                  : status == 'Offline'
                      ? AppColors.softGray
                      : status == 'Maybe'
                          ? AppColors.secondaryLavender
                          : AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    this.hint,
    this.obscure = false,
    this.controller,
    this.errorText,
  });

  final String label;
  final String? hint;
  final bool obscure;
  final TextEditingController? controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
        ),
      ),
    );
  }
}
