import 'package:chatview/chatview.dart';
import 'package:flutter/material.dart';

class ReationBottomSheet extends ChangeNotifier {
  Reaction? _reaction;

  Reaction? get reaction => _reaction;

  set value(Reaction? reaction) {
    _reaction = reaction;
    notifyListeners();
  }

  @override
  void dispose() {
    _reaction = null;
    super.dispose();
  }
}
