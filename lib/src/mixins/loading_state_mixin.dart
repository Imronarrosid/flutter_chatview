import 'package:flutter/material.dart';

mixin LoadingStateMixin<T extends StatefulWidget> on State<T> {
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);

  ValueNotifier<bool> get isLoading => _isLoading;

  Future<void> withLoading(Future<void> Function() action) async {
    if (_isLoading.value) {
      return;
    }
    _isLoading.value = true;
    try {
      await action();
    } finally {
      _isLoading.value = false;
    }
  }
}
