import 'package:flutter/material.dart';

class ScheduleHistoryTab extends StatefulWidget {
  const ScheduleHistoryTab({super.key});

  @override
  State<ScheduleHistoryTab> createState() => _ScheduleHistoryTabState();
}

class _ScheduleHistoryTabState extends State<ScheduleHistoryTab> {
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
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
              Tab(text: 'Lịch Làm Việc'),
              Tab(text: 'Lịch Sử Chấm Công'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // ==========================================
                // Sub-tab Lịch làm việc
                // ==========================================
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 5, // Mock data
                  itemBuilder: (context, index) {
                    return Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.brown[100], borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('T${index + 2}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${20 + index}/10', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        title: const Text('Ca Sáng (08:00 - 12:00)'),
                        subtitle: const Text('Chi nhánh Cầu Giấy'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
                
                // ==========================================
                // Sub-tab Lịch sử (kèm bộ lọc khoảng thời gian)
                // ==========================================
                Column(
                  children: [
                    // Bộ lọc thời gian (BR-HIS-03, BR-HIS-04)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey[100],
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _startDate != null && _endDate != null
                                  ? 'Từ ${_startDate!.day}/${_startDate!.month} - Đến ${_endDate!.day}/${_endDate!.month}'
                                  : 'Chọn khoảng thời gian...',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _selectDateRange(context),
                            icon: const Icon(Icons.filter_alt, color: Colors.brown),
                            label: const Text('Lọc', style: TextStyle(color: Colors.brown)),
                          )
                        ],
                      ),

                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: 3, // Mock data
                        itemBuilder: (context, index) {
                          // BR-HIS-06: Chưa check-out thì báo "Đang làm việc"
                          bool isCompleted = index != 0; 
                          
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                isCompleted ? Icons.history : Icons.pending, 
                                color: isCompleted ? Colors.green : Colors.blue
                              ),
                              title: Text('Ngày ${18 - index}/10/2023'),
                              subtitle: Text(
                                isCompleted 
                                ? 'Check-in: 07:55 AM\nCheck-out: 12:05 PM\nTổng: 4h 10m'
                                : 'Check-in: 08:00 AM\nChưa Check-out'
                              ),
                              isThreeLine: true,
                              trailing: Text(
                                isCompleted ? 'Hoàn tất' : 'Chưa hoàn tất',
                                style: TextStyle(
                                  color: isCompleted ? Colors.green : Colors.orange, 
                                  fontWeight: FontWeight.bold
                                )
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
