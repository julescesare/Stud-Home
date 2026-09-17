import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:stud_home/theme/app_colors.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/deduplication_controller.dart';
import '../../../controllers/property_controller.dart';
import '../../../models/property_model.dart';
import '../../../services/cloudinary_service.dart';

const _kIndigo = AppColors.indigo;
const _kIndigoMid = AppColors.indigoMid;
const _kGray50 = AppColors.gray50;
const _kGray200 = AppColors.gray200;
const _kGray400 = AppColors.gray400;
const _kGray700 = AppColors.gray700;
const _kGray800 = AppColors.gray800;

/// Écran de dépôt d'annonce .
///
/// Flux complet à la validation :
/// 1. Upload des photos sélectionnées vers Cloudinary (CloudinaryService).
/// 2. Construction du PropertyModel avec les URLs obtenues.
/// 3. Détection de doublons (DeduplicationController) : recherche d'une
///    annonce similaire déjà publiée (même ville, surface ± 2m², adresse).
/// 4. Écriture dans Firestore via `PropertyController.createProperty()`,
///    avec le clusterId résolu à l'étape précédente si un doublon existe.
/// 5. Confirmation visuelle animée (Lottie) avant de revenir à la recherche.
class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _chargesController = TextEditingController(text: "0");
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _surfaceController = TextEditingController();

  final List<File> _selectedImages = [];
  bool _isFurnished = false;
  bool _acceptsHousingAid = false;
  bool _acceptsPublicGuarantee = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _chargesController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _surfaceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() => _selectedImages.addAll(picked.map((x) => File(x.path))));
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = context.read<AuthController>().currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. Upload des photos vers Cloudinary (peut être vide pour un prototype rapide).
      final imageUrls = _selectedImages.isNotEmpty
          ? await CloudinaryService.uploadImages(_selectedImages)
          : <String>[];

      // 2. Construction du modèle métier (sans clusterId pour l'instant).
      final property = PropertyModel(
        id: '', // ignoré par toFirestore(), Firestore génère l'ID
        ownerId: uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        propertyType: "studio",
        priceAmount:
            double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0,
        currencyCode: "EUR",
        chargesIncluded: false,
        streetAddress: _streetController.text.trim(),
        city: _cityController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        countryCode: "FR",
        surfaceSqm:
            double.tryParse(_surfaceController.text.replaceAll(',', '.')) ?? 0,
        isFurnished: _isFurnished,
        acceptsHousingAid: _acceptsHousingAid,
        acceptsPublicGuarantee: _acceptsPublicGuarantee,
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
      );

      // 3. Détection de doublons : on cherche si une annonce similaire
      //    existe déjà avant de persister celle-ci.
      final clusterId = await DeduplicationController().resolveClusterId(
        property,
      );
      final finalProperty = property.copyWith(clusterId: clusterId);

      // 4. Persistance Firestore via le Controller.
      final success = await context.read<PropertyController>().createProperty(
        finalProperty,
      );

      if (!mounted) return;

      if (success) {
        // 5. Confirmation animée avant de revenir à l'écran de recherche.
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            // La modale se ferme elle-même après un court délai — sans
            // ce Future.delayed interne, le `await showDialog` ci-dessus
            // ne se terminerait jamais (barrierDismissible à false, pas
            // de bouton de fermeture).
            Future.delayed(const Duration(milliseconds: 1200), () {
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }
            });
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/animations/success.json',
                    width: 140,
                    repeat: false,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Annonce publiée avec succès",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        );
        if (mounted) {
          Navigator.of(context).pop(); // revient à l'écran de recherche
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de la publication.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erreur upload photos: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Déposer une annonce",
          style: TextStyle(
            color: _kGray800,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: _kGray800),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildPhotoZone(),
            const SizedBox(height: 16),
            _textField(
              label: "Titre de l'annonce",
              controller: _titleController,
              placeholder: "Ex : Studio lumineux — 12e arrondissement",
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            _textField(
              label: "Description",
              controller: _descriptionController,
              placeholder: "Décrivez votre logement…",
              maxLines: 4,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            _textField(
              label: "Adresse",
              controller: _streetController,
              placeholder: "75 Av. d'Ivry",
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    label: "Ville",
                    controller: _cityController,
                    placeholder: "Paris",
                    validator: _requiredValidator,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _textField(
                    label: "Code postal",
                    controller: _postalCodeController,
                    placeholder: "75013",
                    validator: _requiredValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    label: "Loyer mensuel (€)",
                    controller: _priceController,
                    placeholder: "750",
                    keyboardType: TextInputType.number,
                    validator: _requiredValidator,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _textField(
                    label: "Surface (m²)",
                    controller: _surfaceController,
                    placeholder: "22",
                    keyboardType: TextInputType.number,
                    validator: _requiredValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildTogglesCard(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kIndigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Lottie.asset('assets/animations/loading.json'),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Vérification en cours…",
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        ),
                      ],
                    )
                  : const Text(
                      "Publier l'annonce",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? "Champ requis" : null;

  Widget _buildPhotoZone() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kGray50,
          border: Border.all(color: _kGray200, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: _selectedImages.isEmpty
            ? const Column(
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 28,
                    color: _kIndigoMid,
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Ajouter des photos",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kIndigo,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Glisser-déposer ou prendre une photo",
                    style: TextStyle(fontSize: 10, color: _kGray400),
                  ),
                ],
              )
            : SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == _selectedImages.length) {
                      return Container(
                        width: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kGray200),
                        ),
                        child: const Icon(Icons.add, color: _kGray400),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _selectedImages[i],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kGray700,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: _kGray400, fontSize: 12),
            filled: true,
            fillColor: _kGray50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kGray200, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kGray200, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kIndigo, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTogglesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGray200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          _toggleRow(
            "🛋️ Meublé",
            _isFurnished,
            (v) => setState(() => _isFurnished = v),
          ),
          _toggleRow(
            "🏦 Éligible aux aides (APL, ALS…)",
            _acceptsHousingAid,
            (v) => setState(() => _acceptsHousingAid = v),
          ),
          _toggleRow(
            "✅ Accepte les garanties publiques",
            _acceptsPublicGuarantee,
            (v) => setState(() => _acceptsPublicGuarantee = v),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _toggleRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: _kGray700),
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: _kIndigo),
        ],
      ),
    );
  }
}
