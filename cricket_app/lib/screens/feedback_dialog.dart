import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/feedback_service.dart';

/// A production-quality bottom sheet for collecting user feedback.
///
/// Pre-fills [userName] from the current user's profile.
class FeedbackDialog extends StatefulWidget {
  final String userName;

  const FeedbackDialog({super.key, required this.userName});

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'Bug';
  XFile? _selectedScreenshot;
  bool _isSending = false;

  static const List<String> _categories = [
    'Bug',
    'Feature Request',
    'UI / UX Issue',
    'Performance Issue',
    'Other',
  ];

  static const int _minDescriptionLength = 10;
  static const int _maxDescriptionLength = 1000;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _selectedScreenshot = image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _removeScreenshot() {
    setState(() => _selectedScreenshot = null);
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    final success = await FeedbackService.sendFeedback(
      userName: _nameController.text.trim(),
      category: _selectedCategory,
      description: _descriptionController.text.trim(),
      screenshotPath: _selectedScreenshot?.path,
    );

    if (!mounted) return;

    setState(() => _isSending = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Thank you for your feedback. This helps us improve the app.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      _showRetryDialog();
    }
  }

  void _showRetryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Failed to Send'),
          ],
        ),
        content: const Text(
          'Could not open the email client. Please make sure you have an email app installed on your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitFeedback();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF0D1B2A)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.feedback_outlined,
                    color: Colors.greenAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send Feedback',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D1B2A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Help us improve your experience',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          const Divider(height: 24),

          // Form
          Flexible(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // User Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Your Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E3A5F),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Feedback Category',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E3A5F),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(category),
                                  size: 18,
                                  color: _getCategoryColor(category),
                                ),
                                const SizedBox(width: 8),
                                Text(category),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCategory = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Feedback Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 5,
                        maxLength: _maxDescriptionLength,
                        decoration: InputDecoration(
                          labelText: 'Describe your feedback',
                          hintText:
                              'Please provide details about your feedback...',
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 80),
                            child: Icon(Icons.description_outlined),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E3A5F),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please describe your feedback';
                          }
                          if (value.trim().length < _minDescriptionLength) {
                            return 'Feedback must be at least $_minDescriptionLength characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Screenshot Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.image_outlined,
                                    color: Colors.grey.shade600, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Screenshot (Optional)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_selectedScreenshot != null) ...[
                              // Screenshot preview
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(_selectedScreenshot!.path),
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: _removeScreenshot,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _pickScreenshot,
                                icon: const Icon(Icons.swap_horiz, size: 18),
                                label: const Text('Change Screenshot'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E3A5F),
                                ),
                              ),
                            ] else
                              OutlinedButton.icon(
                                onPressed: _pickScreenshot,
                                icon: const Icon(
                                    Icons.add_photo_alternate_outlined),
                                label: const Text('Add Screenshot'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E3A5F),
                                  side: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSending
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isSending ? null : _submitFeedback,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A5F),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade400,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                elevation: 2,
                              ),
                              child: _isSending
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.send, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Send Feedback',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Bug':
        return Icons.bug_report_outlined;
      case 'Feature Request':
        return Icons.lightbulb_outline;
      case 'UI / UX Issue':
        return Icons.design_services_outlined;
      case 'Performance Issue':
        return Icons.speed_outlined;
      case 'Other':
        return Icons.help_outline;
      default:
        return Icons.feedback_outlined;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Bug':
        return Colors.red;
      case 'Feature Request':
        return Colors.amber.shade700;
      case 'UI / UX Issue':
        return Colors.blue;
      case 'Performance Issue':
        return Colors.orange;
      case 'Other':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
