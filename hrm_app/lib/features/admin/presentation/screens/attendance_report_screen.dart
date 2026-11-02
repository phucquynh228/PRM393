import 'package:flutter/material.dart';
import 'package:hrm_app/core/network/api_error.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/admin/data/attendance_report_exporter.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';

class AttendanceReportScreen extends StatefulWidget {
  final List<dynamic> users, stores;
  final Future<AttendanceReportSummary> Function(AttendanceReportRequest)
  onLoad;
  final Future<bool> Function(AttendanceReportRequest, AttendanceReportFormat)
  onExport;
  const AttendanceReportScreen({
    super.key,
    required this.users,
    required this.stores,
    required this.onLoad,
    required this.onExport,
  });

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  AttendanceReportPeriod _period = AttendanceReportPeriod.month;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  int? _userId, _storeId;
  AttendanceReportSummary? _report;
  String? _error, _exportError;
  bool _loading = true;
  AttendanceReportFormat? _exporting;
  int _generation = 0;

  AttendanceReportRequest get _request => AttendanceReportRequest(
    period: _period,
    date: _date,
    userId: _userId,
    storeId: _storeId,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _report = null;
      _error = null;
      _exportError = null;
    });
    try {
      final report = await widget.onLoad(_request);
      if (mounted && generation == _generation) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = readableApiError(error);
          _loading = false;
        });
      }
    }
  }

  void _change(VoidCallback change) {
    setState(change);
    _load();
  }

  Future<void> _export(AttendanceReportFormat format) async {
    if (_exporting != null ||
        _loading ||
        _report == null ||
        _report!.employees.isEmpty) {
      return;
    }
    setState(() {
      _exporting = format;
      _exportError = null;
    });
    try {
      final saved = await widget.onExport(_request, format);
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã xuất báo cáo ${format == AttendanceReportFormat.excel ? 'Excel' : 'PDF'}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _exportError = readableApiError(error));
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  Widget _filter(
    String label,
    List<dynamic> values,
    int? value,
    ValueChanged<int?> onChanged,
  ) => DropdownButtonFormField<int>(
    initialValue: value ?? 0,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: 0, child: Text('Tất cả')),
      ...values.whereType<Map>().map(
        (row) => DropdownMenuItem<int>(
          value: (row['id'] as num).toInt(),
          child: Text(
            '${row['name']} (#${row['id']})',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ],
    onChanged: _exporting != null
        ? null
        : (id) => _change(() => onChanged(id == 0 ? null : id)),
  );

  Widget _metric(String title, int? value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 12),
            Text(
              value?.toString() ?? '—',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _tableRow(List<Widget> cells, {bool header = false}) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    decoration: BoxDecoration(
      color: header ? AppColors.primarySubtle : null,
      border: const Border(bottom: BorderSide(color: AppColors.borderLight)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: cells[0]),
        for (int i = 1; i < cells.length; i++)
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.topCenter, child: cells[i]),
          ),
      ],
    ),
  );

  Widget _exportButton(AttendanceReportFormat format) {
    final enabled =
        !_loading &&
        _exporting == null &&
        _report != null &&
        _report!.employees.isNotEmpty;
    final label = format == AttendanceReportFormat.excel
        ? 'Xuất Excel'
        : 'Xuất PDF';
    final icon = _exporting == format
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            format == AttendanceReportFormat.excel
                ? Icons.table_chart_outlined
                : Icons.picture_as_pdf_outlined,
          );
    return format == AttendanceReportFormat.excel
        ? FilledButton.icon(
            onPressed: enabled ? () => _export(format) : null,
            icon: icon,
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: enabled ? () => _export(format) : null,
            icon: icon,
            label: Text(label),
          );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _exporting == null,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo chấm công'),
        actions: [
          IconButton(
            tooltip: 'Làm mới báo cáo',
            onPressed: _exporting != null || _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_exporting == null) await _load();
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              'Coffee HRM · ${_request.label}',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'KHOẢNG THỜI GIAN',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    key: const ValueKey('report-period-selector'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      _request.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    childrenPadding: const EdgeInsets.only(top: 12),
                    children: [
                      DropdownButtonFormField<AttendanceReportPeriod>(
                        initialValue: _period,
                        decoration: const InputDecoration(
                          labelText: 'Kỳ báo cáo',
                        ),
                        items: AttendanceReportPeriod.values
                            .map(
                              (period) => DropdownMenuItem(
                                value: period,
                                child: Text(
                                  'Theo ${period.label.toLowerCase()}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _exporting != null
                            ? null
                            : (period) => _change(() => _period = period!),
                      ),
                      const SizedBox(height: 16),
                      if (_period == AttendanceReportPeriod.day)
                        OutlinedButton.icon(
                          onPressed: _exporting != null
                              ? null
                              : () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _date,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100, 12, 31),
                                  );
                                  if (date != null && mounted) {
                                    _change(() => _date = date);
                                  }
                                },
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(_request.label),
                        ),
                      if (_period == AttendanceReportPeriod.month) ...[
                        DropdownButtonFormField<int>(
                          key: const ValueKey('report-month'),
                          initialValue: _date.month,
                          decoration: const InputDecoration(labelText: 'Tháng'),
                          items: List.generate(
                            12,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('Tháng ${i + 1}'),
                            ),
                          ),
                          onChanged: _exporting != null
                              ? null
                              : (month) => _change(
                                  () => _date = DateTime(_date.year, month!),
                                ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_period != AttendanceReportPeriod.day) ...[
                        DropdownButtonFormField<int>(
                          key: const ValueKey('report-year'),
                          initialValue: _date.year,
                          decoration: const InputDecoration(labelText: 'Năm'),
                          items: List.generate(
                            101,
                            (i) => DropdownMenuItem(
                              value: 2000 + i,
                              child: Text('${2000 + i}'),
                            ),
                          ),
                          onChanged: _exporting != null
                              ? null
                              : (year) => _change(
                                  () => _date = DateTime(year!, _date.month),
                                ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(top: 8),
                    title: const Text('Lọc nhân viên và chi nhánh'),
                    children: [
                      _filter(
                        'Nhân viên',
                        widget.users,
                        _userId,
                        (id) => _userId = id,
                      ),
                      const SizedBox(height: 16),
                      _filter(
                        'Chi nhánh làm việc',
                        widget.stores,
                        _storeId,
                        (id) => _storeId = id,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, box) {
                final count = box.maxWidth >= 800 ? 4 : 2;
                final width = (box.maxWidth - (count - 1) * 12) / count;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _metric(
                      'Nhân viên',
                      _report?.employeeCount,
                      Icons.people_outline,
                      AppColors.primary,
                    ),
                    _metric(
                      'Ca đã hoàn thành',
                      _report?.completedShifts,
                      Icons.task_alt,
                      AppColors.success,
                    ),
                    _metric(
                      'Đi muộn',
                      _report?.lateShifts,
                      Icons.schedule,
                      AppColors.warning,
                    ),
                    _metric(
                      'Vắng không phép',
                      _report?.unexcusedAbsences,
                      Icons.person_off_outlined,
                      AppColors.error,
                    ),
                  ].map((card) => SizedBox(width: width, child: card)).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Bảng chấm công nhân viên',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Dữ liệu thực tế · ${AttendanceReportRequest.ymd(_request.from)} đến ${AttendanceReportRequest.ymd(_request.to)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null) ...[
              InlineNotice(_error!, error: true),
              TextButton(onPressed: _load, child: const Text('Thử lại')),
            ] else if (_report != null && _report!.employees.isEmpty)
              const InlineNotice(
                'Không có dữ liệu chấm công trong kỳ và phạm vi đã chọn.',
              )
            else if (_report != null)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _tableRow([
                      for (final title in [
                        'Nhân viên',
                        'Ca làm',
                        'Muộn',
                        'Vắng',
                      ])
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ], header: true),
                    for (final row in _report!.employees)
                      _tableRow([
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.userName),
                            const SizedBox(height: 4),
                            Text(
                              row.employeeCode,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Text('${row.completedShifts}'),
                        Text('${row.lateShifts}'),
                        Text('${row.unexcusedAbsences}'),
                      ]),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Ca làm = ca đã hoàn thành. Đi muộn = vào ca trễ từ 1 phút. Vắng không phép = trạng thái vắng mặt (ABSENT), không gồm nghỉ phép. '
              'Kỳ báo cáo tính theo ngày phân ca, không gồm ca nháp hoặc đã hủy.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (_exportError != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: InlineNotice(_exportError!, error: true),
              ),
            ],
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, box) =>
                  box.maxWidth < 380 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _exportButton(AttendanceReportFormat.excel),
                        const SizedBox(height: 12),
                        _exportButton(AttendanceReportFormat.pdf),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _exportButton(AttendanceReportFormat.excel),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _exportButton(AttendanceReportFormat.pdf),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}
