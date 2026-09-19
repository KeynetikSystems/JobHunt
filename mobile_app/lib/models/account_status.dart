/// The user's own plan/verification/usage status, from GET /api/me.
class AccountStatus {
  final String email;
  final bool emailVerified;
  final String plan;
  final int materialsUsedToday;
  final int? materialsDailyCap; // null = unlimited (premium)

  const AccountStatus({
    required this.email,
    required this.emailVerified,
    required this.plan,
    required this.materialsUsedToday,
    required this.materialsDailyCap,
  });

  bool get isPremium => plan == 'premium';

  factory AccountStatus.fromJson(Map<String, dynamic> json) {
    return AccountStatus(
      email: json['email'] ?? '',
      emailVerified: json['email_verified'] ?? false,
      plan: json['plan'] ?? 'free',
      materialsUsedToday: json['materials_used_today'] ?? 0,
      materialsDailyCap: json['materials_daily_cap'] as int?,
    );
  }
}
