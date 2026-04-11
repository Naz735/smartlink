List<double> extractFeatures(String url) {
  List<double> features = [
    usingIP(url),
    longURL(url),
    shortURL(url),
    symbolAt(url),
    redirecting(url),
    prefixSuffix(url),
    subDomains(url),
    httpsToken(url),
  ];

  print("Features: $features");
  print("Feature length: ${features.length}");

  return features;
}

// FEATURES

double usingIP(String url) =>
    RegExp(r'\d+\.\d+\.\d+\.\d+').hasMatch(url) ? -1.0 : 1.0;

double longURL(String url) {
  if (url.length < 54) return 1.0;
  if (url.length <= 75) return 0.0;
  return -1.0;
}

double shortURL(String url) =>
    (url.contains("bit.ly") || url.contains("tinyurl")) ? -1.0 : 1.0;

double symbolAt(String url) =>
    url.contains("@") ? -1.0 : 1.0;

double redirecting(String url) =>
    url.lastIndexOf("//") > 7 ? -1.0 : 1.0;

double prefixSuffix(String url) =>
    url.contains("-") ? -1.0 : 1.0;

double subDomains(String url) {
  int dots = '.'.allMatches(url).length;

  if (dots == 1) return 1.0;
  if (dots == 2) return 0.0;
  return -1.0;
}

double httpsToken(String url) =>
    url.startsWith("https") ? 1.0 : -1.0;