import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pjpacktrack/model/user_repo/my_user.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<MyUser?> fetchUser(String userId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('users').doc(userId).get();

      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          return MyUser(
              userId: userId,
              email: data['email'],
              fullname: data['fullname'] ?? 'Unknown User',
              picture: data['picture'],
              phonenumber: data['phonenumber'],
              birthday: (data['birthday'] as Timestamp).toDate(),
              role: data['role'],
              status: data['status'],
              rank: data['free'],
              limit: 50,
              quantity: 0);
        }
      }
      return null;
    } catch (e) {
      print("Error fetching user: $e");
      return null;
    }
  }

  Future<void> updateUser(MyUser user) async {
    try {
      // Tham chiếu đến document của user dựa trên userId
      DocumentReference userDocRef =
          _firestore.collection('users').doc(user.userId);

      // Tạo một map chứa dữ liệu cần cập nhật
      Map<String, dynamic> userData = {
        'fullname': user.fullname,
        'email': user.email,
        'phonenumber': user.phonenumber,
        'picture': user.picture,
        'birthday': user.birthday,
      };

      // Cập nhật dữ liệu lên Firestore
      await userDocRef.update(userData);
      print("User information updated successfully");
    } catch (e) {
      print("Error updating user information: $e");
      rethrow;
    }
  }

  Future<String?> uploadPicture(String? file, String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'picture': file,
      });

      // Trả về URL của ảnh đã tải lên
      return file;
    } catch (e) {
      print("Error uploading image: $e");
      rethrow; // Ném lại ngoại lệ để xử lý bên ngoài nếu cần
    }
  }

// Future<String> _getCurrentUserName() async {
//   User? user = FirebaseAuth.instance.currentUser;

//   if (user != null) {
//     // Assuming you store the username in Firestore or some other place
//     DocumentSnapshot userDoc = await FirebaseFirestore.instance
//         .collection('users')
//         .doc(user.uid)
//         .get();

//     if (userDoc.exists) {
//       // Get the 'name' field from the user document (make sure to replace 'name' with the actual field name)
//       return userDoc['name'] ??
//           'Tên người dùng'; // Return a fallback name if not found
//     } else {
//       return 'Tên người dùng'; // Fallback if user document doesn't exist
//     }
//   } else {
//     throw Exception('User is not logged in');
//   }
// }
}
