/*
 * Copyright (c) 2022 Simform Solutions
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import 'dart:convert';

import 'package:flutter/material.dart';

import '../conditional/conditional.dart';
import '../utils/constants/constants.dart';
import '../values/enumeration.dart';
import '../values/typedefs.dart';

class ProfileImageWidget extends StatelessWidget {
  const ProfileImageWidget({
    super.key,
    this.imageUrl,
    this.defaultAvatarImage = profileImage,
    this.circleRadius,
    this.assetImageErrorBuilder,
    this.networkImageErrorBuilder,
    this.imageType = ImageType.network,
    required this.networkImageProgressIndicatorBuilder,
    this.imageProviderBuilder,
    this.imageHeaders,
  });

  /// Allow user to set radius of circle avatar.
  final double? circleRadius;

  /// Allow user to pass image url of user's profile picture.
  final String? imageUrl;

  /// Flag to check whether image is network or asset
  final ImageType? imageType;

  /// Field to set default avatar image if profile image link not provided
  final String defaultAvatarImage;

  /// Error builder to build error widget for asset image
  final AssetImageErrorBuilder? assetImageErrorBuilder;

  /// Error builder to build error widget for network image
  final ImageErrorWidgetBuilder? networkImageErrorBuilder;

  final Map<String, String>? imageHeaders;

  /// Progress indicator builder for network image

  final ImageLoadingBuilder? networkImageProgressIndicatorBuilder;

  /// This feature allows you to use a custom image provider.
  /// This is useful if you want to manage image loading yourself, or if you need to cache images.
  /// You can also use the `cached_network_image` feature, but when it comes to caching, you might want to decide on a per-message basis.
  /// Plus, by using this provider, you can choose whether or not to send specific headers based on the URL.
  final ImageProvider Function({
    required String uri,
    required Map<String, String>? imageHeaders,
    required Conditional conditional,
  })? imageProviderBuilder;

  @override
  Widget build(BuildContext context) {
    final radius = (circleRadius ?? 20) * 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(circleRadius ?? 20),
      child: switch (imageType) {
        ImageType.asset when (imageUrl?.isNotEmpty ?? false) => Image.asset(
            imageUrl!,
            height: radius,
            width: radius,
            fit: BoxFit.cover,
            errorBuilder: assetImageErrorBuilder ?? _errorWidget,
          ),
        ImageType.network when (imageUrl?.isNotEmpty ?? false) => Image(
            fit: BoxFit.cover,
            height: radius,
            width: radius,
            image: imageProviderBuilder != null
                ? imageProviderBuilder!(
                    uri: imageUrl ?? defaultAvatarImage,
                    imageHeaders: imageHeaders,
                    conditional: Conditional(),
                  )
                : Conditional().getProvider(
                    imageUrl ?? defaultAvatarImage,
                    headers: imageHeaders,
                  ),
            loadingBuilder: networkImageProgressIndicatorBuilder,
            errorBuilder: networkImageErrorBuilder ??
                (context, error, stackTrace) => const Center(
                      child: Icon(
                        Icons.error_outline,
                        size: 18,
                      ),
                    ),
          ),
        ImageType.base64 when (imageUrl?.isNotEmpty ?? false) => Image.memory(
            base64Decode(imageUrl!),
            height: radius,
            width: radius,
            fit: BoxFit.cover,
            errorBuilder: assetImageErrorBuilder ?? _errorWidget,
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _errorWidget(context, error, stackTrace) {
    return const Center(
      child: Icon(
        Icons.error_outline,
        size: 18,
      ),
    );
  }
}
