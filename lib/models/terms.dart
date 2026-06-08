class TermsSection {
  final int number;
  final String title;
  final String content;

  TermsSection({
    required this.number,
    required this.title,
    required this.content,
  });

  factory TermsSection.fromJson(Map<String, dynamic> json) {
    return TermsSection(
      number: json['number'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'title': title,
      'content': content,
    };
  }
}

class TermsData {
  final String id;
  final String title;
  final String lastUpdated;
  final String importantNotice;
  final List<String> userRequirements;
  final List<TermsSection> sections;
  final String intellectualProperty;
  final String limitationLiability;
  final String changesNotice;
  final String contactInfo;
  final int version;

  TermsData({
    required this.id,
    required this.title,
    required this.lastUpdated,
    required this.importantNotice,
    required this.userRequirements,
    required this.sections,
    required this.intellectualProperty,
    required this.limitationLiability,
    required this.changesNotice,
    required this.contactInfo,
    required this.version,
  });

  factory TermsData.fromJson(Map<String, dynamic> json) {
    List<TermsSection> sections = [];
    if (json['termsSections'] != null) {
      sections = (json['termsSections'] as List)
          .map((s) => TermsSection.fromJson(s))
          .toList();
    }

    List<String> requirements = [];
    if (json['termsUserRequirements'] != null) {
      requirements = (json['termsUserRequirements'] as List)
          .map((r) => r.toString())
          .toList();
    }

    return TermsData(
      id: json['_id'] ?? '',
      title: json['termsOfServiceTitle'] ?? 'Terms of Service',
      lastUpdated: json['termsOfServiceLastUpdated'] ?? '',
      importantNotice: json['termsImportantNotice'] ?? '',
      userRequirements: requirements,
      sections: sections,
      intellectualProperty: json['termsIntellectualProperty'] ?? '',
      limitationLiability: json['termsLimitationLiability'] ?? '',
      changesNotice: json['termsChangesNotice'] ?? '',
      contactInfo: json['termsContactInfo'] ?? '',
      version: json['version'] ?? 1,
    );
  }
}