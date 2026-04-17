import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class _DocEntry {
  final String docType;
  final String label;
  final bool isRequired;

  const _DocEntry({
    required this.docType,
    required this.label,
    this.isRequired = true,
  });
}

const _documents = [
  _DocEntry(docType: 'aadhaar_front', label: 'Aadhaar Card Front'),
  _DocEntry(docType: 'aadhaar_back', label: 'Aadhaar Card Back'),
  _DocEntry(docType: 'license_front', label: 'Driving License Front'),
  _DocEntry(docType: 'license_back', label: 'Driving License Back'),
  _DocEntry(docType: 'vehicle_photo', label: 'Car / Vehicle Photo'),
];

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final _picker = ImagePicker();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  // docType → picked file
  final Map<String, File> _pickedFiles = {};
  // docType → upload progress (0.0 – 1.0)
  final Map<String, double> _uploadProgress = {};
  // docType → uploaded download URL
  final Map<String, String> _uploadedUrls = {};

  bool _isSubmitting = false;

  int get _uploadedCount => _uploadedUrls.length;
  bool get _allUploaded => _uploadedCount == _documents.length;

  Future<void> _pickImage(String docType) async {
    final source = await _showSourceDialog();
    if (source == null) return;

    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (xFile == null) return;

      setState(() {
        _pickedFiles[docType] = File(xFile.path);
        _uploadProgress.remove(docType);
        _uploadedUrls.remove(docType);
      });

      await _uploadFile(docType, File(xFile.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppColors.emergency,
          ),
        );
      }
    }
  }

  Future<ImageSource?> _showSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.accentBlue,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.navy,
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadFile(String docType, File file) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('drivers/$_uid/docs/$docType');

      final uploadTask = ref.putFile(file);

      uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted) return;
        final progress =
            snapshot.bytesTransferred / snapshot.totalBytes;
        setState(() => _uploadProgress[docType] = progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _uploadedUrls[docType] = downloadUrl;
          _uploadProgress.remove(docType);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadProgress.remove(docType));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed for $docType: $e'),
            backgroundColor: AppColors.emergency,
          ),
        );
      }
    }
  }

  Future<void> _submitDocuments() async {
    if (!_allUploaded) return;

    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_uid)
          .update({
        'verificationStatus': 'pending',
        'documents': _uploadedUrls,
        'docsSubmittedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        context.go('/driver/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: AppColors.emergency,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.lightBg,
          appBar: AppBar(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            title: const Text('Document Verification'),
            elevation: 0,
          ),
          body: Column(
            children: [
              _buildProgressHeader(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _documents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    return _buildDocCard(doc);
                  },
                ),
              ),
              _buildSubmitButton(),
            ],
          ),
        ),
        if (_isSubmitting)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.emergency),
                  SizedBox(height: 16),
                  Text(
                    'Submitting documents...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_uploadedCount of ${_documents.length} documents uploaded',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _documents.isEmpty
                  ? 0
                  : _uploadedCount / _documents.length,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.onlineGreen,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Please upload clear photos of all required documents.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(_DocEntry doc) {
    final file = _pickedFiles[doc.docType];
    final progress = _uploadProgress[doc.docType];
    final url = _uploadedUrls[doc.docType];
    final isUploaded = url != null;
    final isUploading = progress != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUploaded
              ? AppColors.onlineGreen.withValues(alpha: 0.4)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Thumbnail / placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 72,
                child: file != null
                    ? Image.file(file, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.lightBg,
                        child: Icon(
                          _iconForDoc(doc.docType),
                          color: AppColors.textLight,
                          size: 32,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // Info + progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          doc.label,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: doc.isRequired
                              ? AppColors.emergency.withValues(alpha: 0.1)
                              : AppColors.accentBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          doc.isRequired ? 'Required' : 'Optional',
                          style: TextStyle(
                            color: doc.isRequired
                                ? AppColors.emergency
                                : AppColors.accentBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (isUploading) ...[
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accentBlue),
                      minHeight: 4,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uploading ${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: AppColors.accentBlue,
                        fontSize: 11,
                      ),
                    ),
                  ] else if (isUploaded) ...[
                    Row(
                      children: const [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.onlineGreen, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Uploaded successfully',
                          style: TextStyle(
                            color: AppColors.onlineGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      'Tap to upload',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Pick button
            GestureDetector(
              onTap: isUploading ? null : () => _pickImage(doc.docType),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isUploaded
                      ? AppColors.onlineGreen.withValues(alpha: 0.1)
                      : AppColors.accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isUploaded
                      ? Icons.edit_rounded
                      : Icons.add_a_photo_rounded,
                  color: isUploaded
                      ? AppColors.onlineGreen
                      : AppColors.accentBlue,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForDoc(String docType) {
    switch (docType) {
      case 'aadhaar_front':
      case 'aadhaar_back':
        return Icons.credit_card_rounded;
      case 'license_front':
      case 'license_back':
        return Icons.badge_rounded;
      case 'vehicle_photo':
        return Icons.directions_car_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Widget _buildSubmitButton() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _allUploaded && !_isSubmitting ? _submitDocuments : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navy,
            disabledBackgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.grey.shade500,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Text(
            _allUploaded
                ? 'Submit Documents'
                : 'Upload all ${_documents.length} documents to continue',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
