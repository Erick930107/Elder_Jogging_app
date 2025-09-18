import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 獲取當前用戶
  User? get currentUser => _auth.currentUser;

  // 獲取用戶狀態流
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 檢查用戶是否已登入
  bool get isLoggedIn => _auth.currentUser != null;

  // 用戶註冊
  Future<UserCredential?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required int age,
    required String gender,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 更新用戶顯示名稱
      await result.user?.updateDisplayName(name);

      // 在 Firestore 中創建用戶資料
      await _createUserProfile(
        uid: result.user!.uid,
        email: email,
        name: name,
        age: age,
        gender: gender,
      );

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('註冊失敗：$e');
    }
  }

  // 用戶登入
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('登入失敗：$e');
    }
  }

  // Google 登入
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(credential);

      // 檢查是否為新用戶，如果是則創建用戶資料
      if (result.additionalUserInfo?.isNewUser == true) {
        await _createUserProfile(
          uid: result.user!.uid,
          email: result.user!.email!,
          name: result.user!.displayName ?? '用戶',
          age: 0, // 需要後續補充
          gender: '未設定',
        );
      }

      return result;
    } catch (e) {
      throw Exception('Google 登入失敗：$e');
    }
  }

  // 登出
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception('登出失敗：$e');
    }
  }

  // 重設密碼
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('重設密碼失敗：$e');
    }
  }

  // 創建用戶資料
  Future<void> _createUserProfile({
    required String uid,
    required String email,
    required String name,
    required int age,
    required String gender,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'name': name,
      'age': age,
      'gender': gender,
      'dailyGoal': 5000, // 預設每日步數目標
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 獲取用戶資料
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (_auth.currentUser == null) return null;

      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      throw Exception('獲取用戶資料失敗：$e');
    }
  }

  // 更新用戶資料
  Future<void> updateUserProfile({
    String? name,
    int? age,
    String? gender,
    int? dailyGoal,
  }) async {
    try {
      if (_auth.currentUser == null) throw Exception('用戶未登入');

      final Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) {
        updateData['name'] = name;
        await _auth.currentUser!.updateDisplayName(name);
      }
      if (age != null) updateData['age'] = age;
      if (gender != null) updateData['gender'] = gender;
      if (dailyGoal != null) updateData['dailyGoal'] = dailyGoal;

      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update(updateData);
    } catch (e) {
      throw Exception('更新用戶資料失敗：$e');
    }
  }

  // 處理 Firebase Auth 異常
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return '密碼強度不足，請使用至少6個字符';
      case 'email-already-in-use':
        return '此電子郵件已被使用';
      case 'invalid-email':
        return '電子郵件格式不正確';
      case 'user-not-found':
        return '找不到此用戶';
      case 'wrong-password':
        return '密碼錯誤';
      case 'user-disabled':
        return '此帳戶已被停用';
      case 'too-many-requests':
        return '請求過於頻繁，請稍後再試';
      case 'operation-not-allowed':
        return '此登入方式未啟用';
      default:
        return '驗證失敗：${e.message}';
    }
  }

  // 刪除帳戶
  Future<void> deleteAccount() async {
    try {
      if (_auth.currentUser == null) throw Exception('用戶未登入');

      final String uid = _auth.currentUser!.uid;

      // 刪除 Firestore 中的用戶資料和運動記錄
      final WriteBatch batch = _firestore.batch();

      // 刪除用戶資料
      batch.delete(_firestore.collection('users').doc(uid));

      // 刪除用戶的運動記錄
      final QuerySnapshot exerciseRecords = await _firestore
          .collection('exercises')
          .where('userId', isEqualTo: uid)
          .get();

      for (final doc in exerciseRecords.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // 刪除 Firebase Auth 帳戶
      await _auth.currentUser!.delete();
    } catch (e) {
      throw Exception('刪除帳戶失敗：$e');
    }
  }
}