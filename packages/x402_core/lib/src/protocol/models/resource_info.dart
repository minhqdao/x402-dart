/// Metadata about the digital resource being requested.
class ResourceInfo {
  /// The canonical URL of the resource.
  final String url;

  /// A human-readable description of what the resource provides.
  final String description;

  /// The MIME type of the resource content.
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
