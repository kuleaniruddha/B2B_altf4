class IssueModel {
  final String trackId;
  final String category;
  final String title;
  final String description;
  final String status; // "Pending", "In Progress", "Resolved", "Rejected"
  final DateTime date;
  final double? latitude;
  final double? longitude;
  final String? photoUrl;
  final String? wardNo;
  final String? assignedTo;
  final DateTime? resolvedDate;

  IssueModel({
    required this.trackId,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    required this.date,
    this.latitude,
    this.longitude,
    this.photoUrl,
    this.wardNo,
    this.assignedTo,
    this.resolvedDate,
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    return IssueModel(
      trackId: json['trackId'] ?? json['_id'] ?? '',
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'Pending',
      date: json['date'] != null
          ? DateTime.tryParse(json['date']) ?? DateTime.now()
          : DateTime.now(),
      latitude: json['location']?['latitude']?.toDouble(),
      longitude: json['location']?['longitude']?.toDouble(),
      photoUrl: json['photoUrl'],
      wardNo: json['wardNo'],
      assignedTo: json['assignedTo'],
      resolvedDate: json['resolvedDate'] != null
          ? DateTime.tryParse(json['resolvedDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'category': category,
        'title': title,
        'description': description,
        'status': status,
        'date': date.toIso8601String(),
        if (latitude != null && longitude != null)
          'location': {'latitude': latitude, 'longitude': longitude},
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (wardNo != null) 'wardNo': wardNo,
      };
}