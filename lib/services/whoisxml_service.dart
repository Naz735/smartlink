import 'dart:convert';
import 'package:http/http.dart' as http;

class WhoisXmlInfo {
  final String domainName;
  final String registrarName;
  final String createdDate;
  final String updatedDate;
  final String expiresDate;
  final String domainAge;
  final String status;

  WhoisXmlInfo({
    required this.domainName,
    required this.registrarName,
    required this.createdDate,
    required this.updatedDate,
    required this.expiresDate,
    required this.domainAge,
    required this.status,
  });
}

class WhoisXmlService {
  // Your WhoisXML API key
  static const String apiKey = "at_HgGv6H4Bu5w9FoQlNtWPRt5B2Dhd6";

  Future<WhoisXmlInfo> lookup(String url) async {
    try {
      final domain = _extractDomain(url);

      final response = await http
          .post(
            Uri.parse("https://www.whoisxmlapi.com/whoisserver/WhoisService"),
            headers: {
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "apiKey": apiKey,
              "domainName": domain,
              "outputFormat": "JSON",
            }),
          )
          .timeout(const Duration(seconds: 15));
print("WHOIS Response:");
print(response.body);
      if (response.statusCode != 200) {
        return _failed(domain, "HTTP Error: ${response.statusCode}");
      }

      final data = jsonDecode(response.body);
      final record = data["WhoisRecord"] ?? {};

      final domainName = record["domainName"]?.toString() ?? domain;

      final registrarName = record["registrarName"]?.toString() ??
          record["registryData"]?["registrarName"]?.toString() ??
          "Not available";

      final createdDate = record["createdDateNormalized"]?.toString() ??
          record["createdDate"]?.toString() ??
          record["registryData"]?["createdDateNormalized"]?.toString() ??
          record["registryData"]?["createdDate"]?.toString() ??
          "Not available";

      final updatedDate = record["updatedDateNormalized"]?.toString() ??
          record["updatedDate"]?.toString() ??
          record["registryData"]?["updatedDateNormalized"]?.toString() ??
          record["registryData"]?["updatedDate"]?.toString() ??
          "Not available";

      final expiresDate = record["expiresDateNormalized"]?.toString() ??
          record["expiresDate"]?.toString() ??
          record["registryData"]?["expiresDateNormalized"]?.toString() ??
          record["registryData"]?["expiresDate"]?.toString() ??
          "Not available";

      final status = record["status"]?.toString() ??
          record["registryData"]?["status"]?.toString() ??
          "Not available";

      final domainAge = _calculateDomainAge(createdDate);

      return WhoisXmlInfo(
        domainName: domainName,
        registrarName: registrarName,
        createdDate: createdDate,
        updatedDate: updatedDate,
        expiresDate: expiresDate,
        domainAge: domainAge,
        status: status,
      );
    } catch (e) {
      return _failed("Unknown", "WHOIS lookup failed");
    }
  }

  WhoisXmlInfo _failed(String domain, String status) {
    return WhoisXmlInfo(
      domainName: domain,
      registrarName: "Not available",
      createdDate: "Not available",
      updatedDate: "Not available",
      expiresDate: "Not available",
      domainAge: "Not available",
      status: status,
    );
  }

  String _extractDomain(String url) {
    String fixedUrl = url.trim();

    if (!fixedUrl.startsWith("http://") &&
        !fixedUrl.startsWith("https://")) {
      fixedUrl = "http://$fixedUrl";
    }

    final uri = Uri.parse(fixedUrl);

    return uri.host.replaceFirst("www.", "").toLowerCase();
  }

  String _calculateDomainAge(String createdDate) {
    try {
      if (createdDate == "Not available" || createdDate.isEmpty) {
        return "Not available";
      }

      // Fix WhoisXML date format:
      // Example: 1997-09-15 07:00:00 UTC
      String cleanedDate = createdDate
          .replaceAll(" UTC", "")
          .replaceAll("Z", "")
          .trim();

      DateTime created = DateTime.parse(cleanedDate);
      DateTime now = DateTime.now();

      int days = now.difference(created).inDays;
      int years = days ~/ 365;
      int remainingDays = days % 365;

      if (years > 0) {
        return "$years year(s), $remainingDays day(s)";
      }

      return "$days day(s)";
    } catch (e) {
      return "Not available";
    }
  }
}