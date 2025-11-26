class SpotifyArtistModel {
  final String id;
  final String name;
  final String? imageUrl;
  final List<SpotifyImage> images;
  final int followers;
  final List<String> genres;
  final int popularity;
  final String? externalUrl;

  SpotifyArtistModel({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.images,
    required this.followers,
    required this.genres,
    required this.popularity,
    this.externalUrl,
  });

  factory SpotifyArtistModel.fromJson(Map<String, dynamic> json) {
    return SpotifyArtistModel(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String?,
      images:
          (json['images'] as List<dynamic>?)
              ?.map((img) => SpotifyImage.fromJson(img as Map<String, dynamic>))
              .toList() ??
          [],
      followers: json['followers'] as int? ?? 0,
      genres: (json['genres'] as List<dynamic>?)?.map((genre) => genre.toString()).toList() ?? [],
      popularity: json['popularity'] as int? ?? 0,
      externalUrl: json['externalUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'images': images.map((img) => img.toJson()).toList(),
      'followers': followers,
      'genres': genres,
      'popularity': popularity,
      'externalUrl': externalUrl,
    };
  }

  /// Get the best quality image URL available
  String? getBestImageUrl() {
    if (images.isEmpty) return imageUrl;

    // Sort by size and get the largest
    final sortedImages = List<SpotifyImage>.from(images)
      ..sort((a, b) {
        final aSize = (a.width ?? 0) * (a.height ?? 0);
        final bSize = (b.width ?? 0) * (b.height ?? 0);
        return bSize.compareTo(aSize);
      });

    return sortedImages.first.url;
  }

  /// Get medium quality image (for list items)
  String? getMediumImageUrl() {
    if (images.isEmpty) return imageUrl;

    // Try to get image around 300x300
    final mediumImage = images.firstWhere(
      (img) => (img.width ?? 0) >= 200 && (img.width ?? 0) <= 400,
      orElse: () => images.isNotEmpty ? images.first : SpotifyImage.empty(),
    );

    return mediumImage.url ?? imageUrl;
  }

  /// Format followers count (e.g., 1.5M, 234K)
  String getFormattedFollowers() {
    if (followers >= 1000000) {
      return '${(followers / 1000000).toStringAsFixed(1)}M';
    } else if (followers >= 1000) {
      return '${(followers / 1000).toStringAsFixed(1)}K';
    }
    return followers.toString();
  }
}

class SpotifyImage {
  final String? url;
  final int? width;
  final int? height;

  SpotifyImage({this.url, this.width, this.height});

  factory SpotifyImage.fromJson(Map<String, dynamic> json) {
    return SpotifyImage(url: json['url'] as String?, width: json['width'] as int?, height: json['height'] as int?);
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'width': width, 'height': height};
  }

  factory SpotifyImage.empty() {
    return SpotifyImage(url: null, width: 0, height: 0);
  }
}
