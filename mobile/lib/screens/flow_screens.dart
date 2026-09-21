import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_models.dart';
import '../services/phase_one_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_widgets.dart';

void _go(BuildContext context, Widget page) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => page),
  );
}

String? _required(String value, String label) {
  return value.trim().isEmpty ? '$label is required.' : null;
}

String? _emailError(String value) {
  if (value.trim().isEmpty) return 'Email is required.';
  final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
  return valid ? null : 'Please enter a valid email address.';
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandMark(),
              const Spacer(),
              const Text(
                'Find time for the\npeople who matter.',
                style: AppTypography.heading,
              ),
              const SizedBox(height: 16),
              const Text(
                'Bring your family together, even when life happens in different places.',
                style: AppTypography.body,
              ),
              const SizedBox(height: 36),
              const SoftIllustration(icon: Icons.people_alt_outlined),
              const Spacer(),
              PrimaryButton(
                label: 'Get Started',
                onPressed: () => _go(context, const SignupLoginScreen()),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => _go(context, const DevMemberFlowScreen()),
                  child: const Text('DEV / TESTING ONLY · Member Flow'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SignupLoginScreen extends StatefulWidget {
  const SignupLoginScreen({
    super.key,
    this.invitationFamily,
    this.initialSignup = false,
  });

  final Family? invitationFamily;
  final bool initialSignup;

  @override
  State<SignupLoginScreen> createState() => _SignupLoginState();
}

class _SignupLoginState extends State<SignupLoginScreen> {
  late bool signup = widget.initialSignup;
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  Map<String, String?> errors = {};

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void submit() {
    final nextErrors = <String, String?>{
      if (signup) 'fullName': _required(fullNameController.text, 'Full Name'),
      'email': _emailError(emailController.text),
      'password': _required(passwordController.text, 'Password'),
    };
    if (passwordController.text.isNotEmpty && passwordController.text.length < 8) {
      nextErrors['password'] = 'Password must be at least 8 characters.';
    }
    if (signup) {
      nextErrors['confirmPassword'] = _required(
        confirmPasswordController.text,
        'Confirm Password',
      );
      if (confirmPasswordController.text.isNotEmpty &&
          confirmPasswordController.text != passwordController.text) {
        nextErrors['confirmPassword'] = 'Passwords do not match.';
      }
    }
    setState(() => errors = nextErrors);
    if (nextErrors.values.any((error) => error != null)) return;

    if (signup) {
      AppSession.instance.userName = fullNameController.text.trim();
    }
    final invitationFamily = widget.invitationFamily;
    _go(
      context,
      invitationFamily == null
          ? const NoFamilyScreen()
          : JoinFamilyScreen(family: invitationFamily),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: signup ? 'Create your account' : 'Welcome back',
      subtitle: signup
          ? "Let's make it easier to find time for the people you love."
          : "Let's find some time together.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (signup)
            AppField(
              label: 'Full Name',
              controller: fullNameController,
              errorText: errors['fullName'],
            ),
          AppField(
            label: 'Email',
            controller: emailController,
            errorText: errors['email'],
          ),
          AppField(
            label: 'Password',
            obscure: true,
            controller: passwordController,
            errorText: errors['password'],
          ),
          if (signup)
            AppField(
              label: 'Confirm Password',
              obscure: true,
              controller: confirmPasswordController,
              errorText: errors['confirmPassword'],
            ),
          PrimaryButton(
            label: signup ? 'Create Account' : 'Log In',
            onPressed: submit,
          ),
          const SizedBox(height: 16),
          if (!signup)
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('Forgot password?'),
              ),
            ),
          Center(
            child: TextButton(
              onPressed: () => setState(() => signup = !signup),
              child: Text(
                signup
                    ? 'Already have an account?  Log In'
                    : "Don't have an account?  Create Account",
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NoFamilyScreen extends StatelessWidget {
  const NoFamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Welcome to Synchronicity',
      subtitle: "You're not part of a family yet.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SoftIllustration(icon: Icons.group_add_outlined),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Create a Family',
            onPressed: () => _go(context, const CreateFamilyScreen()),
          ),
          const SizedBox(height: 18),
          const Text(
            'Have an invitation? Open the invitation link your family member sent you.',
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
        ],
      ),
    );
  }
}

class DevMemberFlowScreen extends StatelessWidget {
  const DevMemberFlowScreen({super.key});

  void openAuth(BuildContext context, {required bool signup}) {
    final session = AppSession.instance;
    session.activateTestInvitation();
    final family = session.testInvitationFamily!;
    _go(
      context,
      SignupLoginScreen(
        invitationFamily: family,
        initialSignup: signup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'DEV / TESTING ONLY',
      subtitle: 'Simulate a member opening a family invitation link.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppCard(
            child: Text(
              'Invitation: synchronicity.app/join/ABC123\nFamily: The Ramteke Family',
              style: AppTypography.body,
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Test Existing Account · Login',
            onPressed: () => openAuth(context, signup: false),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Test New Account · Signup',
            onPressed: () => openAuth(context, signup: true),
          ),
        ],
      ),
    );
  }
}

class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  final familyNameController = TextEditingController();

  @override
  void dispose() {
    familyNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Create your family',
      subtitle: 'Give your family a little space to call home.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          AppField(
            label: 'Family Name',
            hint: 'The Cozy Circle',
            controller: familyNameController,
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Create Family',
            onPressed: () {
              AppSession.instance.createFamily(familyNameController.text);
              if (AppSession.instance.family != null) {
                _go(context, const FamilyInvitationScreen());
              }
            },
          ),
        ],
      ),
    );
  }
}

class FamilyInvitationScreen extends StatelessWidget {
  const FamilyInvitationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final family = AppSession.instance.family;
    if (family == null) {
      return const NoFamilyScreen();
    }

    return AppPage(
      title: 'Your family is ready!',
      subtitle: 'Invite the people you want to stay connected with.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SoftIllustration(icon: Icons.link),
          const SizedBox(height: 15),
          Text(family.name, style: AppTypography.title),
          const SizedBox(height: 14),
          AppCard(
            color: AppColors.paleMauve.withValues(alpha: 0.45),
            borderColor: AppColors.lightLavender,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Invitation link', style: AppTypography.label),
                const SizedBox(height: 8),
                Text(
                  family.invitationLink,
                  style: const TextStyle(
                    color: AppColors.deepLavender,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Copy Link',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: family.invitationLink),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Link copied')),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Share',
                        icon: Icons.share_outlined,
                        onPressed: () => Share.share(family.invitationLink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SecondaryButton(
                  label: 'Continue to Timezone Setup',
                  onPressed: () => _go(
                    context,
                    TimezoneSetupScreen(family: family),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class JoinFamilyScreen extends StatelessWidget {
  const JoinFamilyScreen({super.key, required this.family});

  final Family family;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Join ${family.name}?',
      subtitle: "You're invited to join this family on Synchronicity.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SoftIllustration(icon: Icons.people_outline),
          const SizedBox(height: 15),
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.softPink,
                  child: Icon(Icons.home_outlined, color: AppColors.deepLavender),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(family.name, style: AppTypography.title),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Request to Join',
            onPressed: () {
              final session = AppSession.instance;
              if (session.testInvitationExists) {
                session.submitTestJoinRequest();
              }
              _go(context, PendingApprovalScreen(family: family));
            },
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Not Now',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key, required this.family});

  final Family family;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Waiting for approval',
      subtitle:
          'Your request to join ${family.name} is waiting for the family admin.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SoftIllustration(icon: Icons.hourglass_empty),
          const SizedBox(height: 22),
          const AppCard(
            child: Row(
              children: [
                Icon(Icons.schedule, color: AppColors.deepLavender),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "We'll let you know when your request is reviewed.",
                    style: AppTypography.body,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SecondaryButton(
            label: 'Back',
            onPressed: () => Navigator.pop(context),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            const Text(
              'DEV / TESTING ONLY',
              textAlign: TextAlign.center,
              style: AppTypography.label,
            ),
            SecondaryButton(
              label: 'Simulate Admin Approval',
              onPressed: () {
                AppSession.instance.approveTestJoinRequest();
                _go(context, TimezoneSetupScreen(family: family));
              },
            ),
          ],
        ],
      ),
    );
  }
}

class AdminRequestsScreen extends StatelessWidget {
  const AdminRequestsScreen({super.key, required this.family});

  final Family family;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'New family request',
      subtitle: 'Review who is asking to join ${family.name}.',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.softPink,
                child: Text('S'),
              ),
              title: Text('Shruti', style: AppTypography.section),
              subtitle: Text(
                'Wants to join ${family.name}',
                style: AppTypography.body,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Accept',
                    onPressed: () => _go(
                      context,
                      TimezoneSetupScreen(family: family),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(
                    label: 'Reject',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TimezoneSetupScreen extends StatelessWidget {
  const TimezoneSetupScreen({super.key, required this.family});

  final Family family;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Set up your timezone',
      subtitle:
          'Synchronicity uses your timezone to understand when your family is awake and available.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SoftIllustration(icon: Icons.public),
          const SizedBox(height: 15),
          PrimaryButton(
            label: 'Allow Location',
            icon: Icons.location_on_outlined,
            onPressed: () => _go(
              context,
              DetectedTimezoneScreen(family: family),
            ),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Choose Manually',
            onPressed: () => _go(
              context,
              TimezoneSelectionScreen(family: family),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your timezone helps us coordinate family time. You can change it later in Settings.',
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
        ],
      ),
    );
  }
}

class DetectedTimezoneScreen extends StatelessWidget {
  const DetectedTimezoneScreen({super.key, required this.family});

  final Family family;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Detected timezone',
      subtitle: 'We detected your timezone as',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          AppCard(
            child: Center(
              child: Text(
                AppSession.instance.timezone,
                style: AppTypography.title,
              ),
            ),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Confirm',
            onPressed: () => _go(
              context,
              FamilyDashboardScreen(
                family: family,
                members: AppSession.instance.members,
                isAdmin: !AppSession.instance.testJoinRequestApproved,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SecondaryButton(label: 'Change', onPressed: () {}),
        ],
      ),
    );
  }
}

class TimezoneSelectionScreen extends StatefulWidget {
  const TimezoneSelectionScreen({super.key, required this.family});

  final Family family;

  @override
  State<TimezoneSelectionScreen> createState() => _TimezoneSelectionState();
}

class _TimezoneSelectionState extends State<TimezoneSelectionScreen> {
  static const timezones = [
    'Asia/Kolkata',
    'Asia/Dubai',
    'Africa/Nairobi',
    'Europe/London',
    'America/New_York',
    'America/Los_Angeles',
    'Australia/Sydney',
  ];

  late String selectedTimezone = AppSession.instance.timezone;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Choose your timezone',
      subtitle: 'Select the timezone you use most often.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final timezone in timezones)
                  RadioListTile<String>(
                    value: timezone,
                    groupValue: selectedTimezone,
                    title: Text(timezone, style: AppTypography.label),
                    activeColor: AppColors.primaryLavender,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedTimezone = value);
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Continue',
            onPressed: () {
              AppSession.instance.timezone = selectedTimezone;
              _go(
                context,
                DetectedTimezoneScreen(family: widget.family),
              );
            },
          ),
        ],
      ),
    );
  }
}

class FamilyDashboardScreen extends StatelessWidget {
  const FamilyDashboardScreen({
    super.key,
    required this.family,
    this.members = const [
      FamilyMember(name: 'You', time: '7:30 PM', status: 'Available'),
    ],
    this.isAdmin = true,
  });

  final Family family;
  final List<FamilyMember> members;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final hasFamilyRecommendation = members.length > 1;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Good evening, ${AppSession.instance.userName}',
                      style: AppTypography.title,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _go(
                      context,
                      SettingsScreen(isAdmin: isAdmin),
                    ),
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: AppColors.deepLavender,
                    ),
                  ),
                ],
              ),
              Text(family.name, style: AppTypography.body),
              const SizedBox(height: 22),
              const SectionLabel('Your family'),
              AppCard(
                child: Column(
                  children: [
                    for (final member in members)
                      MemberRow(
                        name: member.name,
                        time: member.time,
                        status: member.status,
                        detail: member.detail,
                      ),
                    if (members.length == 1)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'No other family members yet.',
                            style: AppTypography.body,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (hasFamilyRecommendation) ...[
                const SizedBox(height: 24),
              const SectionLabel('Best family call window'),
              GestureDetector(
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: AppColors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  builder: (_) => const HarmonySheet(),
                ),
                child: const AppCard(
                  color: AppColors.white,
                  borderColor: AppColors.softPink,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saturday · 7:30 PM',
                              style: AppTypography.title,
                            ),
                            SizedBox(height: 7),
                            Text(
                              'Everyone is likely to be awake',
                              style: AppTypography.body,
                            ),
                            SizedBox(height: 8),
                            Text('Why this time?', style: AppTypography.label),
                          ],
                        ),
                      ),
                      Text(
                        '91%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepLavender,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const SectionLabel('Other good moments'),
              const AppCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Saturday · 8:00 PM',
                        style: AppTypography.label,
                      ),
                      trailing: Text('87%', style: AppTypography.section),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Sunday · 6:30 PM',
                        style: AppTypography.label,
                      ),
                      trailing: Text('82%', style: AppTypography.section),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Join Family Call',
                icon: Icons.videocam_outlined,
                onPressed: () => _go(
                  context,
                  VideoCallPlaceholderScreen(family: family),
                ),
              ),
              ] else ...[
                const SizedBox(height: 24),
                const SectionLabel("Find your family's best time"),
                const AppCard(
                  color: AppColors.paleMauve,
                  child: Text(
                    'Once your family members join, Synchronicity will find a time that works well for everyone.',
                    style: AppTypography.body,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HarmonySheet extends StatelessWidget {
  const HarmonySheet({super.key});

  @override
  Widget build(BuildContext context) {
    const signals = <Map<String, String>>[
      {'label': 'Calendar availability', 'value': '40%'},
      {'label': 'Awake probability', 'value': '25%'},
      {'label': 'Historical acceptance', 'value': '20%'},
      {'label': 'Preference match', 'value': '10%'},
      {'label': 'Schedule stability', 'value': '5%'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Why is this the best time?', style: AppTypography.title),
          const SizedBox(height: 4),
          const Text(
            'Saturday · 7:30 PM    Harmony 91%',
            style: AppTypography.body,
          ),
          const SizedBox(height: 22),
          ...signals.map(
            (signal) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      signal['label']!,
                      style: AppTypography.label,
                    ),
                  ),
                  Text(signal['value']!, style: AppTypography.label),
                ],
              ),
            ),
          ),
          const Text(
            'Synchronicity looks at these signals together to find a time that works well for everyone.',
            style: AppTypography.body,
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.isAdmin = false});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final sections = <String, List<String>>{
      'PROFILE': [
        'Name · ${AppSession.instance.userName}',
        'Email · ishvari@example.com',
      ],
      'YOUR TIME': [
        'Timezone · ${AppSession.instance.timezone}',
        'Current location/timezone · India Standard Time',
      ],
      'AVAILABILITY': [
        'Availability · Available',
        'Sleep schedule · 11:00 PM – 7:00 AM',
      ],
      'CALL PREFERENCES': [
        'Preferred call duration · 20 minutes',
        'Preferred calling times · Evenings',
      ],
      'NOTIFICATIONS': ['Notifications · On'],
      'FAMILY': [
        'Family Information · ${AppSession.instance.family?.name ?? 'No family yet'}',
        'Invite Family Members · Share an invitation',
      ],
    };

    if (isAdmin) {
      sections['ADMIN CONTROLS'] = [
        'Pending Join Requests',
        'Manage Members',
        'Remove Member',
        'Family Administration',
      ];
    }

    return AppPage(
      title: 'Settings',
      subtitle: 'Make Synchronicity feel right for you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in sections.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionLabel(section.key),
                  AppCard(
                    child: Column(
                      children: [
                        for (final item in section.value)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: isAdmin && item == 'Pending Join Requests'
                                ? () => _go(
                                      context,
                                      AdminRequestsScreen(
                                        family: AppSession.instance.family!,
                                      ),
                                    )
                                : null,
                            leading: const Icon(
                              Icons.circle_outlined,
                              color: AppColors.secondaryLavender,
                              size: 20,
                            ),
                            title: Text(item, style: AppTypography.label),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.secondaryText,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class PreCallScreen extends StatelessWidget {
  const PreCallScreen({
    super.key,
    required this.family,
    this.participants = const [],
  });

  final Family family;
  final List<FamilyMember> participants;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Family Call',
      subtitle: family.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SoftIllustration(icon: Icons.videocam_outlined),
          const AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.calendar_today_outlined,
                color: AppColors.deepLavender,
              ),
              title: Text(
                'Saturday · 7:30 PM',
                style: AppTypography.section,
              ),
              subtitle: Text('20 minutes', style: AppTypography.body),
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Joining your call'),
          AppCard(
            child: Column(
              children: [
                for (final member in participants)
                  MemberRow(
                    name: member.name,
                    time: member.time,
                    status: 'Joining',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Join Family Call',
            icon: Icons.videocam_outlined,
            onPressed: () => _go(
              context,
              VideoCallPlaceholderScreen(family: family),
            ),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Not Now',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class VideoCallPlaceholderScreen extends StatelessWidget {
  const VideoCallPlaceholderScreen({super.key, required this.family});

  final Family family;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Family Call',
      subtitle: '${family.name} · Daily.co integration point',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SoftIllustration(icon: Icons.videocam_outlined),
          const SizedBox(height: 20),
          const AppCard(
            child: Text(
              'This is the Phase 1 video-call integration point. The Daily.co room will be connected here in a future release.',
              style: AppTypography.body,
            ),
          ),
          const SizedBox(height: 20),
          SecondaryButton(
            label: 'Back to Dashboard',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
