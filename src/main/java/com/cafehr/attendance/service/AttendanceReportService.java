package com.cafehr.attendance.service;

import com.cafehr.attendance.dto.AttendanceReportRow;
import com.cafehr.attendance.dto.AttendanceReportSummary;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.schedule.entity.ScheduleStatus;
import com.cafehr.schedule.repository.UserScheduleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.Arrays;
import java.util.List;
import java.util.Comparator;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AttendanceReportService {
    private final UserScheduleRepository schedules;

    public record ReportFile(String filename, byte[] bytes) {}
    public record Snapshot(AttendanceReportSummary summary, List<AttendanceReportRow> rows, String filename) {}

    @Transactional(readOnly = true)
    public Snapshot snapshot(String period, String date, Long userId, Long storeId) {
        LocalDate anchor;
        try {
            anchor = LocalDate.parse(date);
        } catch (DateTimeParseException | NullPointerException ex) {
            throw new BusinessException("Ngày báo cáo phải có định dạng yyyy-MM-dd");
        }
        if (anchor.getYear() < 2000 || anchor.getYear() > 2100) {
            throw new BusinessException("Năm báo cáo phải từ 2000 đến 2100");
        }
        if ((userId != null && userId <= 0) || (storeId != null && storeId <= 0)) {
            throw new BusinessException("Mã nhân viên hoặc chi nhánh không hợp lệ");
        }
        LocalDate from;
        LocalDate to;
        switch (period == null ? "" : period) {
            case "day" -> { from = anchor; to = anchor; }
            case "month" -> { from = anchor.withDayOfMonth(1); to = from.plusMonths(1).minusDays(1); }
            case "year" -> { from = anchor.withDayOfYear(1); to = from.plusYears(1).minusDays(1); }
            default -> throw new BusinessException("Kỳ báo cáo phải là day, month hoặc year");
        }

        var rows = schedules.findAttendanceReport(from, to, userId, storeId);
        var employees = rows.stream().collect(Collectors.groupingBy(AttendanceReportRow::userId))
                .entrySet().stream().map(entry -> {
                    var records = entry.getValue();
                    return new AttendanceReportSummary.Employee(entry.getKey(),
                            "NV-" + String.format("%04d", entry.getKey()), records.get(0).userName(),
                            records.stream().filter(AttendanceReportService::completed).count(),
                            records.stream().filter(r -> lateMinutes(r) > 0).count(),
                            records.stream().filter(r -> r.status() == ScheduleStatus.ABSENT).count());
                }).sorted(Comparator.comparing(AttendanceReportSummary.Employee::userName, String.CASE_INSENSITIVE_ORDER)
                        .thenComparing(AttendanceReportSummary.Employee::userId)).toList();
        String scope = (userId == null ? "Tất cả nhân viên" : "Nhân viên #" + userId)
                + " | " + (storeId == null ? "Tất cả chi nhánh" : "Chi nhánh #" + storeId);
        var summary = new AttendanceReportSummary(period, from, to, scope, employees.size(),
                employees.stream().mapToLong(AttendanceReportSummary.Employee::completedShifts).sum(),
                employees.stream().mapToLong(AttendanceReportSummary.Employee::lateShifts).sum(),
                employees.stream().mapToLong(AttendanceReportSummary.Employee::unexcusedAbsences).sum(), employees);
        String filename = "bao-cao-cham-cong_" + from + "_" + to
                + (userId == null ? "" : "_nv-" + userId)
                + (storeId == null ? "" : "_cn-" + storeId);
        return new Snapshot(summary, rows, filename);
    }

    @Transactional(readOnly = true)
    public ReportFile export(String period, String date, Long userId, Long storeId) {
        var report = snapshot(period, date, userId, storeId);
        if (report.rows().isEmpty()) throw new BusinessException("Không có dữ liệu chấm công trong kỳ đã chọn");

        // UTF-8 BOM allows Excel to display Vietnamese correctly.
        StringBuilder csv = new StringBuilder("\uFEFF");
        csv.append(line("Ngày làm việc", "Mã ca phân công", "Mã nhân viên", "Nhân viên",
                "Mã chi nhánh", "Chi nhánh", "Ca làm", "Giờ bắt đầu", "Giờ kết thúc",
                "Vào ca", "Ra ca", "Số phút làm thực tế", "Trạng thái", "Đã điều chỉnh"));
        for (AttendanceReportRow row : report.rows()) {
            Object workedMinutes = row.checkInTime() == null || row.checkOutTime() == null ? ""
                    : Math.max(0, Duration.between(row.checkInTime(), row.checkOutTime()).toMinutes());
            csv.append(line(row.date(), row.scheduleId(), "NV-" + String.format("%04d", row.userId()),
                    row.userName(), row.storeCode(), row.storeName(), row.shiftName(),
                    row.startTime(), row.endTime(), row.checkInTime(), row.checkOutTime(), workedMinutes,
                    status(row.status()), Boolean.TRUE.equals(row.manuallyAdjusted()) ? "Có" : "Không"));
        }
        return new ReportFile(report.filename() + ".csv", csv.toString().getBytes(StandardCharsets.UTF_8));
    }

    public static boolean completed(AttendanceReportRow row) {
        return row.checkInTime() != null && row.checkOutTime() != null;
    }

    public static long lateMinutes(AttendanceReportRow row) {
        return row.checkInTime() == null ? 0 : Math.max(0,
                Duration.between(row.date().atTime(row.startTime()), row.checkInTime()).toMinutes());
    }

    public static String status(ScheduleStatus status) {
        return switch (status) {
            case PENDING -> "Chưa chấm công";
            case CHECKED_IN -> "Đang làm";
            case CHECKED_OUT -> "Hoàn thành";
            case ABSENT -> "Vắng mặt";
            case ON_LEAVE -> "Nghỉ phép";
            case CANCELLED -> "Đã hủy";
        };
    }

    private static String line(Object... values) {
        return Arrays.stream(values).map(AttendanceReportService::cell).collect(Collectors.joining(",")) + "\r\n";
    }

    private static String cell(Object value) {
        String text = value == null ? "" : value.toString();
        // Quote CSV delimiters/newlines and prevent user-entered names from becoming Excel formulas.
        String leading = text.stripLeading();
        if ((!leading.isEmpty() && "=+-@".indexOf(leading.charAt(0)) >= 0)
                || text.startsWith("\t") || text.startsWith("\r") || text.startsWith("\n")) text = "'" + text;
        return "\"" + text.replace("\"", "\"\"") + "\"";
    }
}
