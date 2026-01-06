/// Resource information for payment models
class ResourceInfo {
  /// URL of the resource
  final String url;

  /// Description of the resource
  final String description;

  /// MIME type of the resource
  final String mimeType;

  const ResourceInfo({
    required this.url,
    required this.description,
    required this.mimeType,
  });

  factory ResourceInfo.fromJson(Map<String, dynamic> json) {
    return ResourceInfo(
      url: json['url'] as String,
      description: json['description'] as String,
      mimeType: json['mimeType'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'description': description,
      'mimeType': mimeType,
    };
  }
}
