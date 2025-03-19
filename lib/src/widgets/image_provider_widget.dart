import 'package:chatview/src/conditional/conditional.dart';
import 'package:flutter/material.dart';

class ImageProviderWidget extends StatelessWidget {
  const ImageProviderWidget({
    super.key,
    required this.imageUri,
    required this.imageHeaders,
    this.imageProviderBuilder,
    this.fit,
    this.width,
    this.height,
  });

  final String imageUri;
  final Map<String, String>? imageHeaders;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final ImageProvider Function({
    required String uri,
    required Map<String, String>? imageHeaders,
    required Conditional conditional,
  })? imageProviderBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      child: Image(
        image: imageProviderBuilder != null
            ? imageProviderBuilder!(
                uri: imageUri,
                imageHeaders: imageHeaders,
                conditional: Conditional(),
              )
            : Conditional().getProvider(
                imageUri,
                headers: imageHeaders,
              ),
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      ),
    );
  }
}
