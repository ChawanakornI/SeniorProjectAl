import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

/// Photo preview screen for confirming saved photos with swipeable carousel.
/// Does NOT show predictions - predictions are shown after Case Summary.
class PhotoPreviewScreen extends StatefulWidget {
  final String imagePath;
  final List<String>? imagePaths; // New: List of all image paths
  final String? caseId;
  final bool isMultiImage;
  final int? imageCount;

  const PhotoPreviewScreen({
    super.key,
    required this.imagePath,
    this.imagePaths,
    this.caseId,
    this.isMultiImage = false,
    this.imageCount,
  });

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  List<String> get _allImages => widget.imagePaths ?? [widget.imagePath];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMultipleImages = _allImages.length > 1;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF282828) : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            children: [
              // 1. Image carousel or single image preview
              Expanded(
                flex: 3,
                child:
                    hasMultipleImages
                        ? _buildImageCarousel(isDark)
                        : _buildSingleImage(),
              ),

              const SizedBox(height: 12),

              // Page indicator dots (only for multiple images)
              if (hasMultipleImages) _buildPageIndicator(isDark),

              const SizedBox(height: 16),

              // 2. Success status section
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        hasMultipleImages
                            ? 'Photos Captured!'
                            : 'Photo Captured!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Case: ${widget.caseId ?? "-"} | ${_allImages.length} image${_allImages.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (hasMultipleImages) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Swipe to preview all images',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.blue[300] : Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Do you want to save ${hasMultipleImages ? "these images" : "this image"}?',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'After saving, you can run AI prediction from the Case Summary.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Save and Retake buttons
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Return true to indicate save confirmed
                    Navigator.of(context).pop(
                      {
                      'confirmed':true,
                      'predictionIndex': _currentPage,
                      });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    hasMultipleImages
                        ? 'Save All Images (${_allImages.length})'
                        : 'Save Image',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  // Return false to indicate retake
                  Navigator.of(context).pop(false);
                },
                child: Text(
                  'Retake',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Single image preview (original behavior)
  Widget _buildSingleImage() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: FileImage(File(widget.imagePath)),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
    );
  }

  /// Swipeable image carousel for multiple images
  Widget _buildImageCarousel(bool isDark) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: _allImages.length,
          onPageChanged: (index) {
            setState(() => _currentPage = index);
          },
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: FileImage(File(_allImages[index])),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Image counter overlay
        Positioned(
          top: 16,
          right: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentPage + 1} / ${_allImages.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'selected for prediction',
                      style: TextStyle(color: Color(0xFFF0EAD6), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  ),
              ),
            ),
        )
      ],
    );
  }

  /// Page indicator dots
  Widget _buildPageIndicator(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_allImages.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color:
                isActive
                    ? const Color(0xFF007AFF)
                    : (isDark ? Colors.white24 : Colors.grey.shade300),
          ),
        );
      }),
    );
  }
}
