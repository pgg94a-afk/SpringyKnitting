enum StitchType {
  knit, // K - 겉뜨기
  purl, // P - 안뜨기
}

class Stitch {
  final StitchType type;

  const Stitch(this.type);

  String get abbreviation {
    switch (type) {
      case StitchType.knit:
        return 'K';
      case StitchType.purl:
        return 'P';
    }
  }

  String get koreanName {
    switch (type) {
      case StitchType.knit:
        return '겉뜨기';
      case StitchType.purl:
        return '안뜨기';
    }
  }
}
