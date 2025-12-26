class YoutubeVideo {
  final String id;
  final String videoId;
  final String title;
  final String url;

  YoutubeVideo({
    required this.id,
    required this.videoId,
    required this.title,
    required this.url,
  });

  static String? extractVideoId(String url) {
    // YouTube URL patterns:
    // https://www.youtube.com/watch?v=VIDEO_ID
    // https://youtu.be/VIDEO_ID
    // https://www.youtube.com/embed/VIDEO_ID
    // https://m.youtube.com/watch?v=VIDEO_ID

    final regexPatterns = [
      RegExp(r'youtube\.com\/watch\?v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be\/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/embed\/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/v\/([a-zA-Z0-9_-]{11})'),
    ];

    for (final regex in regexPatterns) {
      final match = regex.firstMatch(url);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  static bool isValidYoutubeUrl(String url) {
    return extractVideoId(url) != null;
  }
}
