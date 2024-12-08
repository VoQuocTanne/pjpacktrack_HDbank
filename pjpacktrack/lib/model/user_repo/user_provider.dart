import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pjpacktrack/model/user_repo/my_user.dart';
import 'user_service.dart';

// Provider for the UserService instance
final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

// Provider for fetching MyUser data
final userProvider =
    FutureProvider.family<MyUser?, String>((ref, userId) async {
  final userService = ref.watch(userServiceProvider);
  return userService.fetchUser(userId);
});
// Provider for uploading a profile picture and updating user's picture URL
final uploadPictureProvider =
    FutureProvider.family<String?, MyUser>((ref, params) async {
  final userService = ref.watch(userServiceProvider);
  return userService.uploadPicture(params.picture, params.userId);
});

final uploadUserProvider =
    FutureProvider.family<void, MyUser>((ref, params) async {
  final userService = ref.watch(userServiceProvider);
  userService.updateUser(params);
});
Future<void> updateUserPackage(String userId, String packageId) async {
  try {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    // Kiểm tra người dùng tồn tại
    final docSnapshot = await userRef.get();
    if (!docSnapshot.exists) {
      throw Exception("Người dùng không tồn tại.");
    }

    // Cập nhật gói dịch vụ
    await userRef.update({
      'packageId': packageId, // Lưu ID của gói
      // 'updatedAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    throw Exception("Không thể cập nhật gói: $e");
  }
}

Future<void> updateUserVideoLimit(String userId, int videoLimit) async {
  try {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    // Kiểm tra xem người dùng có tồn tại hay không
    final userSnapshot = await userRef.get();
    if (!userSnapshot.exists) {
      throw Exception("Người dùng không tồn tại.");
    }

    // Cập nhật số lượng video giới hạn
    await userRef.update({'package': videoLimit});

    debugPrint("Đã cập nhật giới hạn video: $videoLimit");
  } catch (e) {
    debugPrint("Lỗi khi cập nhật giới hạn video: $e");
    throw Exception("Lỗi khi cập nhật giới hạn video: $e");
  }
}
