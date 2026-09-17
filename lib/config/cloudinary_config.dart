/// Configuration Cloudinary pour l'upload des photos d'annonces.
///
/// À remplir avec les valeurs de ton compte Cloudinary (cloudinary.com/console) :
/// - [cloudName] : visible en haut du Dashboard ("Cloud name").
/// - [uploadPreset] : à créer dans Settings > Upload > Upload presets.
///   Choisis impérativement le mode "Unsigned" — c'est ce qui permet
///   d'uploader directement depuis l'app Flutter sans exposer de clé API secrète.
class CloudinaryConfig {
  static const String cloudName = "dyz5hqu8r";
  static const String uploadPreset = "studhome";

  static String get uploadUrl =>
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload";
}
