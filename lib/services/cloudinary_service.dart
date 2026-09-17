import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/cloudinary_config.dart';

/// Service responsable du téléversement des photos d'annonces vers Cloudinary.
///
/// Remplace Firebase Storage dans l'architecture (cf. dossier de conception,
/// section 4) : Firestore reste la source de vérité pour les métadonnées,
/// seule l'URL retournée par Cloudinary est stockée dans `PropertyModel.imageUrls`.
///
/// Ce service ne fait que l'upload brut — c'est le Controller qui décide
/// quand l'appeler et quoi faire du résultat (respect du MVC : un Service
/// n'est pas un Controller, il n'a pas d'état ni de logique métier).
class CloudinaryService {
  /// Upload une image et retourne son URL sécurisée (https).
  /// Lève une exception si l'upload échoue (réseau, preset invalide, etc.).
  static Future<String> uploadImage(File imageFile) async {
    final request =
        http.MultipartRequest('POST', Uri.parse(CloudinaryConfig.uploadUrl))
          ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
          ..files.add(
            await http.MultipartFile.fromPath('file', imageFile.path),
          );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception(
        "Échec de l'upload Cloudinary (${response.statusCode}): $responseBody",
      );
    }

    // On extrait `secure_url` sans dépendance JSON supplémentaire (dart:convert suffit).
    final match = RegExp(r'"secure_url":"([^"]+)"').firstMatch(responseBody);
    if (match == null) {
      throw Exception("Réponse Cloudinary inattendue: $responseBody");
    }
    return match.group(1)!.replaceAll(r'\/', '/');
  }

  /// Upload plusieurs images séquentiellement et retourne leurs URLs.
  /// Séquentiel plutôt qu'en parallèle : évite de saturer la connexion
  /// mobile de l'utilisateur si plusieurs photos volumineuses sont envoyées.
  static Future<List<String>> uploadImages(List<File> imageFiles) async {
    final urls = <String>[];
    for (final file in imageFiles) {
      urls.add(await uploadImage(file));
    }
    return urls;
  }
}
