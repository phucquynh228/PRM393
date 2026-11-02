import 'package:flutter/material.dart';

import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/empty_state_view.dart';

/// Search/filter once, display readable cards on phones or paginated tables on wide screens.
class DirectoryList extends StatefulWidget {
  final String title, subtitle;
  final List<dynamic> items;
  final List<String> searchFields;
  final Widget Function(Map<String, dynamic>) itemBuilder;
  final Future<void> Function() onRefresh;
  final Widget? action, leading;
  final String? filterField, dateField;
  final String initialFilter;
  final DateTime? initialDate;
  final Map<String, String> filterOptions;
  final List<Widget> additionalFilters;
  final List<String>? columns;
  final List<DataCell> Function(Map<String, dynamic>)? cells;
  const DirectoryList({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.searchFields,
    required this.itemBuilder,
    required this.onRefresh,
    this.initialFilter = '',
    this.initialDate,
    this.action,
    this.leading,
    this.filterField,
    this.dateField,
    this.filterOptions = const {},
    this.additionalFilters = const [],
    this.columns,
    this.cells,
  });
  @override
  State<DirectoryList> createState() => _DirectoryListState();
}

class _DirectoryListState extends State<DirectoryList> {
  String _query = '';
  late String _filter = widget.initialFilter;
  late DateTime? _date = widget.initialDate;
  int _rows = 10;
  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(
          (item) =>
              widget.searchFields.any(
                (key) => (item[key]?.toString() ?? '').toLowerCase().contains(
                  _query.toLowerCase().trim(),
                ),
              ) &&
              (_filter.isEmpty ||
                  item[widget.filterField]?.toString() == _filter) &&
              (_date == null ||
                  DateUtils.isSameDay(
                    DateTime.tryParse(item[widget.dateField]?.toString() ?? ''),
                    _date,
                  )),
        )
        .toList();
    return LayoutBuilder(
      builder: (context, box) => RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            PageHeading(
              title: widget.title,
              subtitle: widget.subtitle,
              action: widget.action,
            ),
            if (widget.leading != null) widget.leading!,
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: box.maxWidth >= 760
                      ? 360
                      : (box.maxWidth - 40).clamp(0, 600).toDouble(),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      labelText: 'Tìm kiếm',
                      hintText: 'Nhập tên hoặc thông tin cần tìm',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                if (widget.filterField != null)
                  SizedBox(
                    width: box.maxWidth >= 760
                        ? 220
                        : (box.maxWidth - 40).clamp(0, 600).toDouble(),
                    child: DropdownButtonFormField<String>(
                      initialValue: _filter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Lọc trạng thái / vai trò',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Tất cả'),
                        ),
                        ...widget.filterOptions.entries.map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _filter = value ?? ''),
                    ),
                  ),
                ...widget.additionalFilters.map(
                  (filter) => SizedBox(
                    width: box.maxWidth >= 760
                        ? 220
                        : (box.maxWidth - 40).clamp(0, 600).toDouble(),
                    child: filter,
                  ),
                ),
                if (widget.dateField != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _date ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (date != null && mounted) setState(() => _date = date);
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _date == null
                          ? 'Chọn ngày'
                          : '${_date!.day}/${_date!.month}/${_date!.year}',
                    ),
                  ),
                if (_date != null)
                  TextButton(
                    onPressed: () => setState(() => _date = null),
                    child: const Text('Bỏ lọc ngày'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${items.length} kết quả',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const EmptyStateView(
                icon: Icons.search_off,
                title: 'Chưa có kết quả',
                message: 'Thử thay đổi bộ lọc hoặc thêm dữ liệu mới.',
              )
            else if (box.maxWidth >= 900 &&
                widget.columns != null &&
                widget.cells != null)
              Card(
                clipBehavior: Clip.antiAlias,
                child: PaginatedDataTable(
                  key: ValueKey('$_query/$_filter/$_date/${items.length}'),
                  columns: widget.columns!
                      .map((name) => DataColumn(label: Text(name)))
                      .toList(),
                  source: _DirectorySource(items, widget.cells!),
                  rowsPerPage: _rows,
                  availableRowsPerPage: const [10, 20, 50],
                  onRowsPerPageChanged: (value) =>
                      setState(() => _rows = value ?? 10),
                  showEmptyRows: false,
                  headingRowHeight: 52,
                  dataRowMinHeight: 64,
                  dataRowMaxHeight: 88,
                ),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: widget.itemBuilder(item),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _DirectorySource extends DataTableSource {
  final List<Map<String, dynamic>> items;
  final List<DataCell> Function(Map<String, dynamic>) cells;
  _DirectorySource(this.items, this.cells);
  @override
  DataRow? getRow(int index) => index >= items.length
      ? null
      : DataRow.byIndex(index: index, cells: cells(items[index]));
  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => items.length;
  @override
  int get selectedRowCount => 0;
}
