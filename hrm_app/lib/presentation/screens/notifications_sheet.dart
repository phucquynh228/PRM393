import 'package:flutter/material.dart';

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thông báo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: ListView(
              children: const [
                ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Đơn xin nghỉ phép đã được duyệt'),
                  subtitle: Text('Ngày 20/10/2023. Quản lý: Trần Admin.'),
                ),
                ListTile(
                  leading: Icon(Icons.swap_horiz, color: Colors.blue),
                  title: Text('Yêu cầu đổi ca thành công'),
                  subtitle: Text('Đổi ca Sáng T3 với Nguyễn B.'),
                ),
                ListTile(
                  leading: Icon(Icons.schedule, color: Colors.orange),
                  title: Text('Lịch làm việc tuần mới đã có'),
                  subtitle: Text('Vui lòng kiểm tra lịch làm việc tuần tới.'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
