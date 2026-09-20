/// The user's personal profile: name/contact details plus structured work history,
/// education, and skills. Backs GET/PUT /api/profile. full_name/phone/location/
/// linkedin are reference fields for the user's own use when filling out application
/// forms elsewhere; work_history/education/skills are what actually grounds AI
/// drafting via POST /api/materials.
class UserProfile {
  final String fullName;
  final String phone;
  final String location;
  final String linkedinUrl;
  final String workHistory;
  final String education;
  final String skills;

  const UserProfile({
    this.fullName = '',
    this.phone = '',
    this.location = '',
    this.linkedinUrl = '',
    this.workHistory = '',
    this.education = '',
    this.skills = '',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      location: json['location'] ?? '',
      linkedinUrl: json['linkedin_url'] ?? '',
      workHistory: json['work_history'] ?? '',
      education: json['education'] ?? '',
      skills: json['skills'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'phone': phone,
        'location': location,
        'linkedin_url': linkedinUrl,
        'work_history': workHistory,
        'education': education,
        'skills': skills,
      };
}
