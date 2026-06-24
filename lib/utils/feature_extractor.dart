import 'package:http/http.dart' as http;
import '../services/whoisxml_service.dart';

Future<List<double>> extractFeatures(String url) async {
  String normalizedUrl = normalizeUrl(url);
  String domain = getDomain(normalizedUrl);

  WhoisXmlInfo whoisInfo = await WhoisXmlService().lookup(url);
  String html = await fetchHtml(normalizedUrl);
  print("HTML length: ${html.length}");
  print("Domain: $domain");

  List<double> features = [
    usingIP(domain),                 // 1. UsingIP
    longURL(url),                    // 2. LongURL
    shortURL(url),                   // 3. ShortURL
    symbolAt(url),                   // 4. Symbol@
    redirecting(url),                // 5. Redirecting//
    prefixSuffix(domain),            // 6. PrefixSuffix-
    subDomains(domain),              // 7. SubDomains
    httpsToken(normalizedUrl),       // 8. HTTPS
    domainRegLen(whoisInfo),         // 9. DomainRegLen
    favicon(html),                   // 10. Favicon
    nonStdPort(normalizedUrl),       // 11. NonStdPort
    httpsDomainURL(domain),          // 12. HTTPSDomainURL
    requestURL(html, domain),        // 13. RequestURL
    anchorURL(html, domain),         // 14. AnchorURL
    linksInScriptTags(html, domain), // 15. LinksInScriptTags
    serverFormHandler(html, domain), // 16. ServerFormHandler
    infoEmail(url, html),            // 17. InfoEmail
    abnormalURL(url),                // 18. AbnormalURL
    websiteForwarding(url),          // 19. WebsiteForwarding
    statusBarCust(html),             // 20. StatusBarCust
    disableRightClick(html),         // 21. DisableRightClick
    usingPopupWindow(html),          // 22. UsingPopupWindow
    iframeRedirection(html),         // 23. IframeRedirection
    ageOfDomain(whoisInfo),          // 24. AgeofDomain
    dnsRecording(whoisInfo),         // 25. DNSRecording

    websiteTraffic(domain, whoisInfo, normalizedUrl),   // 26. WebsiteTraffic
    pageRank(domain, whoisInfo, normalizedUrl),          // 27. PageRank
    googleIndex(domain, whoisInfo),                      // 28. GoogleIndex
    linksPointingToPage(domain, whoisInfo),              // 29. LinksPointingToPage
    statsReport(url, html, domain),                      // 30. StatsReport
  ];


  return features;
}

// =========================
// HELPER FUNCTIONS
// =========================

String normalizeUrl(String url) {
  String fixedUrl = url.trim();

  if (!fixedUrl.startsWith("http://") &&
      !fixedUrl.startsWith("https://")) {
    fixedUrl = "http://$fixedUrl";
  }

  return fixedUrl;
}

Uri? parseUrl(String url) {
  try {
    return Uri.parse(normalizeUrl(url));
  } catch (e) {
    return null;
  }
}

String getDomain(String url) {
  try {
    Uri? uri = parseUrl(url);

    if (uri == null || uri.host.isEmpty) {
      return url.toLowerCase();
    }

    return uri.host.toLowerCase().replaceFirst("www.", "");
  } catch (e) {
    return url.toLowerCase();
  }
}

Future<String> fetchHtml(String url) async {
  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode >= 200 && response.statusCode < 400) {
      return response.body.toLowerCase();
    }

    return "";
  } catch (e) {
    return "";
  }
}

DateTime? parseWhoisDate(String dateText) {
  try {
    if (dateText == "Not available" || dateText.isEmpty) {
      return null;
    }

    String cleanedDate = dateText
        .replaceAll(" UTC", "")
        .replaceAll("Z", "")
        .trim();

    return DateTime.parse(cleanedDate);
  } catch (e) {
    return null;
  }
}

int extractDaysFromDomainAge(String domainAge) {
  try {
    if (domainAge == "Not available") return -1;

    int totalDays = 0;

    RegExp yearRegex = RegExp(r'(\d+)\s*year');
    RegExp monthRegex = RegExp(r'(\d+)\s*month');
    RegExp dayRegex = RegExp(r'(\d+)\s*day');

    Match? yearMatch = yearRegex.firstMatch(domainAge);
    Match? monthMatch = monthRegex.firstMatch(domainAge);
    Match? dayMatch = dayRegex.firstMatch(domainAge);

    if (yearMatch != null) {
      totalDays += int.parse(yearMatch.group(1)!) * 365;
    }

    if (monthMatch != null) {
      totalDays += int.parse(monthMatch.group(1)!) * 30;
    }

    if (dayMatch != null) {
      totalDays += int.parse(dayMatch.group(1)!);
    }

    return totalDays;
  } catch (e) {
    return -1;
  }
}

bool isPopularDomain(String domain) {
  List<String> popularDomains = [
    "google.com",
    "youtube.com",
    "facebook.com",
    "instagram.com",
    "whatsapp.com",
    "microsoft.com",
    "apple.com",
    "amazon.com",
    "wikipedia.org",
    "netflix.com",
    "linkedin.com",
    "github.com",
    "yahoo.com",
    "bing.com",
    "shopee.com.my",
    "lazada.com.my",
    "maybank2u.com.my",
    "cimbclicks.com.my",
    "rhbgroup.com",
    "publicbank.com.my",
    "touchngo.com.my",
  ];

  return popularDomains.any((item) {
    return domain == item || domain.endsWith(".$item");
  });
}

// =========================
// 1. UsingIP
// =========================

double usingIP(String domain) {
  return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(domain)
      ? -1.0
      : 1.0;
}

// =========================
// 2. LongURL
// =========================

double longURL(String url) {
  if (url.length < 54) return 1.0;
  if (url.length <= 75) return 0.0;
  return -1.0;
}

// =========================
// 3. ShortURL
// =========================

double shortURL(String url) {
  String lowerUrl = url.toLowerCase();

  List<String> shorteners = [
    "bit.ly",
    "tinyurl",
    "goo.gl",
    "t.co",
    "ow.ly",
    "is.gd",
    "buff.ly",
    "adf.ly",
  ];

  return shorteners.any((s) => lowerUrl.contains(s)) ? -1.0 : 1.0;
}

// =========================
// 4. Symbol@
// =========================

double symbolAt(String url) {
  return url.contains("@") ? -1.0 : 1.0;
}

// =========================
// 5. Redirecting//
// =========================

double redirecting(String url) {
  return url.lastIndexOf("//") > 7 ? -1.0 : 1.0;
}

// =========================
// 6. PrefixSuffix-
// =========================

double prefixSuffix(String domain) {
  return domain.contains("-") ? -1.0 : 1.0;
}

// =========================
// 7. SubDomains
// =========================

double subDomains(String domain) {
  int dots = ".".allMatches(domain).length;

  if (dots <= 1) return 1.0;
  if (dots == 2) return 0.0;
  return -1.0;
}

// =========================
// 8. HTTPS
// =========================

double httpsToken(String url) {
  return url.toLowerCase().startsWith("https://") ? 1.0 : -1.0;
}

// =========================
// 9. DomainRegLen
// =========================

double domainRegLen(WhoisXmlInfo info) {
  try {
    DateTime? created = parseWhoisDate(info.createdDate);
    DateTime? expires = parseWhoisDate(info.expiresDate);

    if (created == null || expires == null) {
      return -1.0;
    }

    int days = expires.difference(created).inDays;

    return days > 365 ? 1.0 : -1.0;
  } catch (e) {
    return -1.0;
  }
}

// =========================
// 10. Favicon
// =========================

double favicon(String html) {
  if (html.isEmpty) return -1.0;

  if (html.contains("rel=\"icon\"") ||
      html.contains("rel='icon'") ||
      html.contains("shortcut icon") ||
      html.contains("favicon")) {
    return 1.0;
  }

  return -1.0;
}

// =========================
// 11. NonStdPort
// =========================

double nonStdPort(String url) {
  try {
    Uri? uri = parseUrl(url);

    if (uri == null) return -1.0;

    if (!uri.hasPort) return 1.0;

    int port = uri.port;

    if (port == 80 || port == 443) {
      return 1.0;
    }

    return -1.0;
  } catch (e) {
    return -1.0;
  }
}

// =========================
// 12. HTTPSDomainURL
// =========================

double httpsDomainURL(String domain) {
  return domain.contains("https") ? -1.0 : 1.0;
}

// =========================
// 13. RequestURL
// =========================

double requestURL(String html, String domain) {
  if (html.isEmpty) return -1.0;

  RegExp srcRegex = RegExp(r'''src=["']([^"']+)["']''');
  Iterable<RegExpMatch> matches = srcRegex.allMatches(html);

  int total = 0;
  int external = 0;

  for (final match in matches) {
    String src = match.group(1) ?? "";

    if (src.isEmpty) continue;

    total++;

    if (src.startsWith("http") && !src.contains(domain)) {
      external++;
    }
  }

  if (total == 0) return 1.0;

  double percentage = external / total;

  if (percentage < 0.22) return 1.0;
  if (percentage <= 0.61) return 0.0;
  return -1.0;
}

// =========================
// 14. AnchorURL
// =========================

double anchorURL(String html, String domain) {
  if (html.isEmpty) return -1.0;

  RegExp hrefRegex = RegExp(r'''href=["']([^"']+)["']''');
  Iterable<RegExpMatch> matches = hrefRegex.allMatches(html);

  int total = 0;
  int suspicious = 0;

  for (final match in matches) {
    String href = match.group(1) ?? "";

    if (href.isEmpty) continue;

    total++;

    if (href == "#" ||
        href.toLowerCase().contains("javascript:void") ||
        href.toLowerCase().contains("mailto:") ||
        (href.startsWith("http") && !href.contains(domain))) {
      suspicious++;
    }
  }

  if (total == 0) return 1.0;

  double percentage = suspicious / total;

  if (percentage < 0.31) return 1.0;
  if (percentage <= 0.67) return 0.0;
  return -1.0;
}

// =========================
// 15. LinksInScriptTags
// =========================

double linksInScriptTags(String html, String domain) {
  if (html.isEmpty) return -1.0;

  RegExp scriptRegex = RegExp(r'''<script[^>]+src=["']([^"']+)["']''');
  Iterable<RegExpMatch> matches = scriptRegex.allMatches(html);

  int total = 0;
  int external = 0;

  for (final match in matches) {
    String src = match.group(1) ?? "";

    if (src.isEmpty) continue;

    total++;

    if (src.startsWith("http") && !src.contains(domain)) {
      external++;
    }
  }

  if (total == 0) return 1.0;

  double percentage = external / total;

  if (percentage < 0.17) return 1.0;
  if (percentage <= 0.81) return 0.0;
  return -1.0;
}

// =========================
// 16. ServerFormHandler
// =========================

double serverFormHandler(String html, String domain) {
  if (html.isEmpty) return -1.0;

  RegExp formRegex = RegExp(r'''<form[^>]+action=["']([^"']*)["']''');
  Iterable<RegExpMatch> matches = formRegex.allMatches(html);

  for (final match in matches) {
    String action = match.group(1) ?? "";

    if (action.isEmpty || action == "about:blank") {
      return -1.0;
    }

    if (action.startsWith("http") && !action.contains(domain)) {
      return 0.0;
    }
  }

  return 1.0;
}

// =========================
// 17. InfoEmail
// =========================

double infoEmail(String url, String html) {
  String content = "${url.toLowerCase()} $html";

  bool hasMailto = content.contains("mailto:");

  bool hasEmailPattern = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  ).hasMatch(content);

  return (hasMailto || hasEmailPattern) ? -1.0 : 1.0;
}

// =========================
// 18. AbnormalURL
// =========================

double abnormalURL(String url) {
  try {
    Uri? uri = parseUrl(url);

    if (uri == null || uri.host.isEmpty) return -1.0;

    if (url.contains("@")) return -1.0;

    return 1.0;
  } catch (e) {
    return -1.0;
  }
}

// =========================
// 19. WebsiteForwarding
// =========================

double websiteForwarding(String url) {
  return redirecting(url);
}

// =========================
// 20. StatusBarCust
// =========================

double statusBarCust(String html) {
  if (html.isEmpty) return -1.0;

  if (html.contains("window.status") ||
      (html.contains("onmouseover") && html.contains("status"))) {
    return -1.0;
  }

  return 1.0;
}

// =========================
// 21. DisableRightClick
// =========================

double disableRightClick(String html) {
  if (html.isEmpty) return -1.0;

  if (html.contains("event.button==2") ||
      html.contains("event.button == 2") ||
      html.contains("contextmenu") ||
      html.contains("oncontextmenu")) {
    return -1.0;
  }

  return 1.0;
}

// =========================
// 22. UsingPopupWindow
// =========================

double usingPopupWindow(String html) {
  if (html.isEmpty) return -1.0;

  if (html.contains("window.open(") || html.contains("alert(")) {
    return -1.0;
  }

  return 1.0;
}

// =========================
// 23. IframeRedirection
// =========================

double iframeRedirection(String html) {
  if (html.isEmpty) return -1.0;

  if (html.contains("<iframe")) {
    return -1.0;
  }

  return 1.0;
}

// =========================
// 24. AgeofDomain
// =========================

double ageOfDomain(WhoisXmlInfo info) {
  int days = extractDaysFromDomainAge(info.domainAge);

  if (days == -1) return -1.0;

  return days >= 180 ? 1.0 : -1.0;
}

// =========================
// 25. DNSRecording
// =========================

double dnsRecording(WhoisXmlInfo info) {
  if (info.domainName == "Unknown" ||
      info.domainName == "Not available" ||
      info.createdDate == "Not available") {
    return -1.0;
  }

  return 1.0;
}

// =========================
// 26. WebsiteTraffic
// =========================

double websiteTraffic(String domain, WhoisXmlInfo info, String url) {
  int ageDays = extractDaysFromDomainAge(info.domainAge);

  if (isPopularDomain(domain)) {
    return 1.0;
  }

  if (ageDays >= 365 && httpsToken(url) == 1.0) {
    return 1.0;
  }

  if (ageDays >= 180) {
    return 0.0;
  }

  return -1.0;
}

// =========================
// 27. PageRank
// =========================

double pageRank(String domain, WhoisXmlInfo info, String url) {
  int ageDays = extractDaysFromDomainAge(info.domainAge);

  if (isPopularDomain(domain)) {
    return 1.0;
  }

  if (ageDays >= 365 &&
      httpsToken(url) == 1.0 &&
      prefixSuffix(domain) == 1.0 &&
      subDomains(domain) != -1.0) {
    return 1.0;
  }

  if (ageDays >= 180 && httpsToken(url) == 1.0) {
    return 0.0;
  }

  return -1.0;
}

// =========================
// 28. GoogleIndex
// =========================

double googleIndex(String domain, WhoisXmlInfo info) {
  int ageDays = extractDaysFromDomainAge(info.domainAge);

  if (isPopularDomain(domain)) {
    return 1.0;
  }

  if (ageDays >= 180) {
    return 1.0;
  }

  return -1.0;
}

// =========================
// 29. LinksPointingToPage
// =========================

double linksPointingToPage(String domain, WhoisXmlInfo info) {
  int ageDays = extractDaysFromDomainAge(info.domainAge);

  if (isPopularDomain(domain)) {
    return 1.0;
  }

  if (ageDays >= 365) {
    return 0.0;
  }

  return -1.0;
}

// =========================
// 30. StatsReport
// =========================

double statsReport(String url, String html, String domain) {
  String lowerUrl = url.toLowerCase();

  int suspiciousScore = 0;

  if (lowerUrl.contains("@")) suspiciousScore++;
  if (domain.contains("-")) suspiciousScore++;
  if (usingIP(domain) == -1.0) suspiciousScore++;
  if (shortURL(lowerUrl) == -1.0) suspiciousScore++;
  if (lowerUrl.length > 75) suspiciousScore++;
  if (html.contains("password") && html.contains("login")) suspiciousScore++;

  if (suspiciousScore >= 2) {
    return -1.0;
  }

  return 1.0;
}