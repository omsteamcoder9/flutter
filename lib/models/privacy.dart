class PrivacySection {
  final int number;
  final String title;
  final String content;

  PrivacySection({
    required this.number,
    required this.title,
    required this.content,
  });

  factory PrivacySection.fromJson(Map<String, dynamic> json) {
    return PrivacySection(
      number: json['number'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
    );
  }
}

class PrivacyData {
  final String id;
  final String title;
  final String lastUpdated;
  final String introduction;
  final List<String> dataCollection;
  final List<String> dataUsage;
  final List<String> dataSharing;
  final String dataSecurity;
  final List<String> userRights;
  final String cookies;
  final String thirdPartyLinks;
  final String policyChanges;
  final String contactInfo;
  final List<PrivacySection> sections;
  final int version;

  PrivacyData({
    required this.id,
    required this.title,
    required this.lastUpdated,
    required this.introduction,
    required this.dataCollection,
    required this.dataUsage,
    required this.dataSharing,
    required this.dataSecurity,
    required this.userRights,
    required this.cookies,
    required this.thirdPartyLinks,
    required this.policyChanges,
    required this.contactInfo,
    required this.sections,
    required this.version,
  });

  factory PrivacyData.fromJson(Map<String, dynamic> json) {
    List<PrivacySection> sections = [];
    if (json['privacySections'] != null) {
      sections = (json['privacySections'] as List)
          .map((s) => PrivacySection.fromJson(s))
          .toList();
    }

    List<String> dataCollection = [];
    if (json['privacyDataCollection'] != null) {
      dataCollection = (json['privacyDataCollection'] as List)
          .map((d) => d.toString())
          .toList();
    }

    List<String> dataUsage = [];
    if (json['privacyDataUsage'] != null) {
      dataUsage = (json['privacyDataUsage'] as List)
          .map((d) => d.toString())
          .toList();
    }

    List<String> dataSharing = [];
    if (json['privacyDataSharing'] != null) {
      dataSharing = (json['privacyDataSharing'] as List)
          .map((d) => d.toString())
          .toList();
    }

    List<String> userRights = [];
    if (json['privacyUserRights'] != null) {
      userRights = (json['privacyUserRights'] as List)
          .map((d) => d.toString())
          .toList();
    }

    return PrivacyData(
      id: json['_id'] ?? '',
      title: json['privacyPolicyTitle'] ?? 'Privacy Policy',
      lastUpdated: json['privacyPolicyLastUpdated'] ?? '',
      introduction: json['privacyIntroduction'] ?? '',
      dataCollection: dataCollection,
      dataUsage: dataUsage,
      dataSharing: dataSharing,
      dataSecurity: json['privacyDataSecurity'] ?? '',
      userRights: userRights,
      cookies: json['privacyCookies'] ?? '',
      thirdPartyLinks: json['privacyThirdPartyLinks'] ?? '',
      policyChanges: json['privacyPolicyChanges'] ?? '',
      contactInfo: json['privacyContactInfo'] ?? '',
      sections: sections,
      version: json['version'] ?? 1,
    );
  }
}