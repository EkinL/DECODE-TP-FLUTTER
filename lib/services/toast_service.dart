import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class ToastService {
  static ToastificationItem showToast(
    String message, {
    ToastificationType type = ToastificationType.error,
  }) {
    toastification.dismissAll();
    return toastification.show(
      title: Text(message),
      type: type,
      autoCloseDuration: const Duration(seconds: 5),
    );
  }
}
