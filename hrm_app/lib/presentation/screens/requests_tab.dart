import 'package:flutter/material.dart';

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  String? _selectedReasonId;

  // Biến lưu trạng thái gửi yêu cầu (Đã gửi chờ duyệt hay chưa)
  bool _isLeaveRequestPending = false;
  bool _isSwapRequestPending = false;

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  void _submitRequest(String type) {
    if (type == 'Nghỉ Phép') {
      // BR-REQ-03: Kiểm tra các trường bắt buộc
      if (_startDateController.text.isEmpty || _endDateController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn Từ ngày và Đến ngày!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_selectedReasonId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn loại lý do nghỉ!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      setState(() {
        _isLeaveRequestPending = true;
      });
    } else if (type == 'Đổi Ca') {
      setState(() {
        _isSwapRequestPending = true;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gửi yêu cầu $type. Vui lòng chờ Quản lý phê duyệt!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    
    // BR-REQ-02: Chọn cùng lúc Từ Ngày - Đến Ngày (Ngày bắt đầu không được sau ngày kết thúc do Picker quản lý)
    // BR-REQ-04: Giới hạn số ngày chọn tối đa, giả sử tối đa 14 ngày
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: tomorrow, 
      lastDate: DateTime.now().add(const Duration(days: 365)), 
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.brown,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final int daysDifference = picked.end.difference(picked.start).inDays + 1;
      
      // Kiểm tra giới hạn số ngày nghỉ
      if (daysDifference > 14) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn chỉ được phép xin nghỉ tối đa 14 ngày liên tiếp!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _startDateController.text = "${picked.start.day.toString().padLeft(2, '0')}/${picked.start.month.toString().padLeft(2, '0')}/${picked.start.year}";
        _endDateController.text = "${picked.end.day.toString().padLeft(2, '0')}/${picked.end.month.toString().padLeft(2, '0')}/${picked.end.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.brown,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.brown,
            tabs: [
              Tab(text: 'Xin Nghỉ Phép'),
              Tab(text: 'Xin Đổi Ca'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // ==========================================
                // Form Nghỉ phép
                // ==========================================
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLeaveRequestPending)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.pending_actions, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bạn đang có yêu cầu xin nghỉ phép chờ phê duyệt. Vui lòng theo dõi tại mục Thông Báo.',
                                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _startDateController,
                              readOnly: true,
                              onTap: _isLeaveRequestPending ? null : () => _selectDateRange(context),
                              decoration: InputDecoration(
                                labelText: 'Từ ngày',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.calendar_today),
                                filled: _isLeaveRequestPending,
                                fillColor: Colors.grey[200],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _endDateController,
                              readOnly: true,
                              onTap: _isLeaveRequestPending ? null : () => _selectDateRange(context),
                              decoration: InputDecoration(
                                labelText: 'Đến ngày',
                                border: const OutlineInputBorder(),
                                filled: _isLeaveRequestPending,
                                fillColor: Colors.grey[200],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Loại lý do', 
                          border: const OutlineInputBorder(),
                          filled: _isLeaveRequestPending,
                          fillColor: Colors.grey[200],
                        ),
                        items: const [
                          DropdownMenuItem(value: 'SICK', child: Text('Ốm đau (SICK)')),
                          DropdownMenuItem(value: 'FAMILY', child: Text('Việc gia đình (FAMILY)')),
                          DropdownMenuItem(value: 'OTHER', child: Text('Khác (OTHER)')),
                        ],
                        onChanged: _isLeaveRequestPending ? null : (v) {
                          setState(() {
                            _selectedReasonId = v;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        maxLines: 3,
                        readOnly: _isLeaveRequestPending,
                        decoration: InputDecoration(
                          labelText: 'Chi tiết lý do', 
                          border: const OutlineInputBorder(),
                          filled: _isLeaveRequestPending,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLeaveRequestPending ? null : () => _submitRequest('Nghỉ Phép'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            disabledBackgroundColor: Colors.grey[400],
                          ),
                          child: Text(_isLeaveRequestPending ? 'Đang Chờ Duyệt...' : 'Gửi Yêu Cầu'),
                        ),
                      )
                    ],
                  ),
                ),

                // ==========================================
                // Form Đổi ca
                // ==========================================
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isSwapRequestPending)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.pending_actions, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bạn đang có một đề nghị đổi ca chờ phê duyệt. Vui lòng chờ phản hồi từ quản lý!',
                                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        readOnly: _isSwapRequestPending,
                        decoration: InputDecoration(
                          labelText: 'Ca của tôi muốn đổi', 
                          border: const OutlineInputBorder(),
                          filled: _isSwapRequestPending,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        readOnly: _isSwapRequestPending,
                        decoration: InputDecoration(
                          labelText: 'Nhân viên nhận ca (SĐT/Mã NV)', 
                          border: const OutlineInputBorder(),
                          filled: _isSwapRequestPending,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        readOnly: _isSwapRequestPending,
                        decoration: InputDecoration(
                          labelText: 'Lý do đổi ca', 
                          border: const OutlineInputBorder(),
                          filled: _isSwapRequestPending,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSwapRequestPending ? null : () => _submitRequest('Đổi Ca'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            disabledBackgroundColor: Colors.grey[400],
                          ),
                          child: Text(_isSwapRequestPending ? 'Đang Chờ Quản Lý Duyệt...' : 'Gửi Đề Nghị Đổi Ca'),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
