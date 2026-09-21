import '../models/app_models.dart';

class AuthService {
  Future<bool> signIn(String email, String password) async {
    return email.isNotEmpty && password.isNotEmpty;
  }

  Future<bool> signUp(String name, String email, String password) async {
    return name.isNotEmpty && email.isNotEmpty && password.isNotEmpty;
  }
}

class AppSession {
  AppSession._();

  static final AppSession instance = AppSession._();

  String userName = 'Shruti';
  String timezone = 'Asia/Kolkata';
  Family? family;
  String? testInvitationToken;
  Family? testInvitationFamily;
  String? testInvitationAdminName;
  bool testInvitationExists = false;
  bool testJoinRequestPending = false;
  bool testJoinRequestApproved = false;
  List<FamilyMember> members = const [
    FamilyMember(name: 'You', time: '7:30 PM', status: 'Available'),
  ];

  void activateTestInvitation() {
    testInvitationToken = 'ABC123';
    testInvitationFamily = const Family(
      name: 'The Ramteke Family',
      invitationLink: 'synchronicity.app/join/ABC123',
    );
    testInvitationAdminName = 'Family Creator';
    testInvitationExists = true;
    testJoinRequestPending = false;
    testJoinRequestApproved = false;
  }

  void submitTestJoinRequest() {
    testJoinRequestPending = true;
    testJoinRequestApproved = false;
  }

  void approveTestJoinRequest() {
    testJoinRequestPending = false;
    testJoinRequestApproved = true;
    members = [
      FamilyMember(
        name: 'You',
        detail: userName,
        time: '7:30 PM',
        status: 'Available',
      ),
      FamilyMember(
        name: testInvitationAdminName ?? 'Family Creator',
        detail: 'Admin',
        time: '7:30 PM',
        status: 'Available',
      ),
    ];
  }

  void createFamily(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    family = Family(
      name: trimmedName,
      invitationLink: 'synchronicity.app/join/ABC123',
    );
    members = const [
      FamilyMember(name: 'You', time: '7:30 PM', status: 'Available'),
    ];
  }
}

class FamilyService {
  const FamilyService();

  Family? get family => AppSession.instance.family;
  List<FamilyMember> get members => AppSession.instance.members;
}

class TimezoneService {
  Future<String> detect() async => 'Asia/Kolkata';
}
