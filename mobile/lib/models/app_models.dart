enum UserRole { member, admin }
enum JoinRequestStatus { pending, approved, rejected }

class FamilyMember {
  const FamilyMember({required this.name, required this.time, required this.status, this.detail});
  final String name;
  final String time;
  final String status;
  final String? detail;
}

class Family {
  const Family({required this.name, required this.invitationLink});
  final String name;
  final String invitationLink;
}

class JoinRequest {
  const JoinRequest({required this.name, required this.familyName, this.status = JoinRequestStatus.pending});
  final String name;
  final String familyName;
  final JoinRequestStatus status;
}

class HarmonyRecommendation {
  const HarmonyRecommendation({required this.day, required this.time, required this.score});
  final String day;
  final String time;
  final int score;
}
