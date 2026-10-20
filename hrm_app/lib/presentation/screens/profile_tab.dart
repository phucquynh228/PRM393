import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _oldPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu cũ'),
                validator: (value) => value == null || value.isEmpty ? 'Vui lòng nhập mật khẩu cũ' : null,
              ),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                  if (value.length < 6) return 'Mật khẩu phải từ 6 ký tự';
                  return null;
                },
              ),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                  if (value != _newPasswordController.text) return 'Mật khẩu không khớp';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () {
            _oldPasswordController.clear();
            _newPasswordController.clear();
            _confirmPasswordController.clear();
            Navigator.pop(ctx);
          }, child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                _oldPasswordController.clear();
                _newPasswordController.clear();
                _confirmPasswordController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đổi mật khẩu thành công! (Mock)'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Cập nhật'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.brown,
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Column(
            children: [
              Text('Nguyễn Văn Nhân Viên', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text('Chức vụ: Nhân viên Pha chế (Staff)', style: TextStyle(color: Colors.grey)),
              Text('SĐT: 0987654321', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.edit, color: Colors.brown),
          title: const Text('Cập nhật thông tin'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng đang phát triển...')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.lock, color: Colors.brown),
          title: const Text('Đổi mật khẩu'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showChangePasswordDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          onTap: () async {
            await const FlutterSecureStorage().delete(key: 'jwt_token');
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
          },
        ),
      ],
    );
  }
}
