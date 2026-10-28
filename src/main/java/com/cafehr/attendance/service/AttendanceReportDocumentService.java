package com.cafehr.attendance.service;

import com.cafehr.attendance.dto.AttendanceReportSummary;
import com.cafehr.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.apache.pdfbox.pdmodel.*;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.PDType0Font;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.text.Normalizer;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

/** Native XLSX and paginated PDF generated from the same summary shown in the app. */
@Service
@RequiredArgsConstructor
public class AttendanceReportDocumentService {
    private final AttendanceReportService reports;

    public AttendanceReportService.ReportFile export(String format, String period, String date, Long userId, Long storeId) {
        if (!List.of("xlsx", "pdf").contains(format)) throw new BusinessException("Định dạng báo cáo không hợp lệ");
        var snapshot = reports.snapshot(period, date, userId, storeId);
        if (snapshot.rows().isEmpty()) throw new BusinessException("Không có dữ liệu chấm công trong kỳ đã chọn");
        try {
            byte[] bytes = format.equals("xlsx") ? excel(snapshot) : pdf(snapshot.summary());
            return new AttendanceReportService.ReportFile(snapshot.filename() + "." + format, bytes);
        } catch (IOException ex) {
            throw new IllegalStateException("Không tạo được báo cáo " + format, ex);
        }
    }

    public static String periodLabel(AttendanceReportSummary summary) {
        return switch (summary.period()) {
            case "month" -> "Tháng " + summary.from().getMonthValue() + "/" + summary.from().getYear();
            case "year" -> "Năm " + summary.from().getYear();
            default -> "Ngày " + summary.from().getDayOfMonth() + "/" + summary.from().getMonthValue() + "/" + summary.from().getYear();
        };
    }

    private byte[] excel(AttendanceReportService.Snapshot snapshot) throws IOException {
        try (var book = new XSSFWorkbook(); var output = new ByteArrayOutputStream()) {
            var titleStyle = style(book, true, 20, IndexedColors.WHITE, IndexedColors.BROWN);
            var headerStyle = style(book, true, 11, IndexedColors.WHITE, IndexedColors.BROWN);
            var bodyStyle = style(book, false, 11, IndexedColors.BLACK, IndexedColors.WHITE);
            var alternateStyle = style(book, false, 11, IndexedColors.BLACK, IndexedColors.LIGHT_YELLOW);
            var metricStyle = style(book, true, 22, IndexedColors.BROWN, IndexedColors.LEMON_CHIFFON);
            var report = snapshot.summary();
            Sheet sheet = book.createSheet("Tong hop");
            sheet.setDisplayGridlines(false);
            put(sheet, 0, titleStyle, "Báo cáo chấm công");
            sheet.addMergedRegion(new CellRangeAddress(0, 0, 0, 4));
            sheet.getRow(0).setHeightInPoints(40);
            put(sheet, 1, bodyStyle, "Coffee HRM | " + periodLabel(report));
            sheet.addMergedRegion(new CellRangeAddress(1, 1, 0, 4));
            put(sheet, 2, bodyStyle, report.scope());
            sheet.addMergedRegion(new CellRangeAddress(2, 2, 0, 4));
            put(sheet, 4, bodyStyle, "Nhân viên", "Ca đã hoàn thành", "Đi muộn", "Vắng không phép");
            sheet.getRow(4).setHeightInPoints(32);
            put(sheet, 5, metricStyle, report.employeeCount(), report.completedShifts(), report.lateShifts(), report.unexcusedAbsences());
            sheet.getRow(5).setHeightInPoints(38);
            put(sheet, 7, headerStyle, "Mã nhân viên", "Nhân viên", "Ca hoàn thành", "Muộn", "Vắng không phép");
            sheet.getRow(7).setHeightInPoints(32);
            int index = 8;
            for (var employee : report.employees()) {
                put(sheet, index, index % 2 == 0 ? bodyStyle : alternateStyle, employee.employeeCode(), employee.userName(),
                        employee.completedShifts(), employee.lateShifts(), employee.unexcusedAbsences());
                sheet.getRow(index++).setHeightInPoints(34);
            }
            put(sheet, index + 1, bodyStyle, "Đi muộn: vào ca trễ từ 1 phút. Vắng không phép: ca có trạng thái ABSENT.");
            sheet.addMergedRegion(new CellRangeAddress(index + 1, index + 1, 0, 4));
            sheet.getRow(index + 1).setHeightInPoints(32);
            int[] widths = {17, 42, 21, 21, 23};
            for (int i = 0; i < widths.length; i++) sheet.setColumnWidth(i, widths[i] * 256);
            sheet.createFreezePane(2, 8);
            sheet.setAutoFilter(new CellRangeAddress(7, index - 1, 0, 4));
            sheet.setRepeatingRows(new CellRangeAddress(7, 7, -1, -1));
            sheet.getPrintSetup().setLandscape(true);
            sheet.getPrintSetup().setPaperSize(PrintSetup.A4_PAPERSIZE);
            sheet.setFitToPage(true);
            sheet.getPrintSetup().setFitWidth((short) 1);
            sheet.getPrintSetup().setFitHeight((short) 0);

            Sheet detail = book.createSheet("Chi tiet");
            detail.setDisplayGridlines(false);
            put(detail, 0, headerStyle, "Ngày làm việc", "Mã ca", "Mã nhân viên", "Nhân viên", "Chi nhánh", "Ca làm",
                    "Bắt đầu", "Kết thúc", "Vào ca", "Ra ca", "Phút làm thực tế", "Phút muộn", "Trạng thái", "Điều chỉnh");
            detail.getRow(0).setHeightInPoints(34);
            index = 1;
            for (var row : snapshot.rows()) {
                Object minutes = !AttendanceReportService.completed(row) ? "" :
                        Math.max(0, Duration.between(row.checkInTime(), row.checkOutTime()).toMinutes());
                put(detail, index, index % 2 == 0 ? alternateStyle : bodyStyle,
                        row.date(), row.scheduleId(), "NV-" + String.format("%04d", row.userId()), row.userName(), row.storeName(),
                        row.shiftName(), row.startTime(), row.endTime(), row.checkInTime(), row.checkOutTime(), minutes,
                        AttendanceReportService.lateMinutes(row), AttendanceReportService.status(row.status()),
                        Boolean.TRUE.equals(row.manuallyAdjusted()) ? "Có" : "Không");
                detail.getRow(index++).setHeightInPoints(32);
            }
            for (int i = 0; i < 14; i++) detail.setColumnWidth(i, (i == 3 || i == 4 ? 35 : i == 8 || i == 9 ? 25 : 19) * 256);
            detail.createFreezePane(4, 1);
            detail.setAutoFilter(new CellRangeAddress(0, index - 1, 0, 13));
            detail.setRepeatingRows(new CellRangeAddress(0, 0, -1, -1));
            book.write(output);
            return output.toByteArray();
        }
    }

    private static CellStyle style(Workbook book, boolean bold, int size, IndexedColors text, IndexedColors background) {
        var style = book.createCellStyle();
        var font = book.createFont();
        font.setFontName("Calibri"); font.setFontHeightInPoints((short) size); font.setBold(bold); font.setColor(text.getIndex());
        style.setFont(font); style.setFillForegroundColor(background.getIndex());
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setVerticalAlignment(VerticalAlignment.CENTER); style.setWrapText(true);
        return style;
    }

    private static void put(Sheet sheet, int index, CellStyle style, Object... values) {
        Row row = sheet.createRow(index);
        for (int i = 0; i < values.length; i++) {
            Cell cell = row.createCell(i);
            Object value = values[i];
            if (value instanceof Number number) cell.setCellValue(number.doubleValue());
            else cell.setCellValue(value == null ? "" : value.toString());
            cell.setCellStyle(style);
        }
    }

    private byte[] pdf(AttendanceReportSummary report) throws IOException {
        try (var document = new PDDocument(); var output = new ByteArrayOutputStream();
             var input = new ClassPathResource("fonts/PlusJakartaSans.ttf").getInputStream()) {
            var font = PDType0Font.load(document, input);
            var info = document.getDocumentInformation();
            info.setTitle("Báo cáo chấm công - " + periodLabel(report)); info.setAuthor("Coffee HRM");
            float[] widths = {65, 240, 70, 70, 70};
            int employee = 0;
            do {
                var page = new PDPage(PDRectangle.A4); document.addPage(page);
                try (var canvas = new PDPageContentStream(document, page)) {
                    text(canvas, font, "Báo cáo chấm công", 40, 788, 24, BROWN);
                    text(canvas, font, "Coffee HRM | " + periodLabel(report), 40, 762, 11, MUTED);
                    float top = 735;
                    if (document.getNumberOfPages() == 1) {
                        rect(canvas, 40, 677, 515, 58, CREAM);
                        text(canvas, font, "KHOẢNG THỜI GIAN", 54, 714, 9, MUTED);
                        text(canvas, font, periodLabel(report), 54, 692, 15, BROWN);
                        String[] labels = {"Nhân viên", "Ca đã hoàn thành", "Đi muộn", "Vắng không phép"};
                        long[] values = {report.employeeCount(), report.completedShifts(), report.lateShifts(), report.unexcusedAbsences()};
                        for (int i = 0; i < 4; i++) {
                            float x = 40 + i * 132;
                            rect(canvas, x, 592, 119, 68, CREAM);
                            text(canvas, font, labels[i], x + 10, 641, 9, MUTED);
                            text(canvas, font, Long.toString(values[i]), x + 10, 610, 23, BROWN);
                        }
                        text(canvas, font, "Bảng chấm công nhân viên", 40, 565, 16, BROWN);
                        text(canvas, font, report.scope(), 40, 546, 9, MUTED);
                        top = 530;
                    }
                    rect(canvas, 40, top - 30, 515, 30, BROWN);
                    String[] headers = {"Mã NV", "Nhân viên", "Ca làm", "Muộn", "Vắng"};
                    float x = 40;
                    for (int i = 0; i < headers.length; i++) {
                        text(canvas, font, headers[i], x + 9, top - 19, 10, Color.WHITE); x += widths[i];
                    }
                    top -= 30;
                    while (employee < report.employees().size()) {
                        var item = report.employees().get(employee);
                        var names = wrap(font, item.userName(), 10, widths[1] - 18);
                        float height = Math.max(36, names.size() * 14 + 16);
                        if (top - height < 100) break;
                        rect(canvas, 40, top - height, 515, height, employee % 2 == 0 ? CREAM : Color.WHITE);
                        text(canvas, font, item.employeeCode(), 49, top - 21, 9, MUTED);
                        for (int line = 0; line < names.size(); line++) text(canvas, font, names.get(line), 114, top - 21 - line * 14, 10, BROWN);
                        text(canvas, font, Long.toString(item.completedShifts()), 354, top - 21, 11, BROWN);
                        text(canvas, font, Long.toString(item.lateShifts()), 424, top - 21, 11, BROWN);
                        text(canvas, font, Long.toString(item.unexcusedAbsences()), 494, top - 21, 11, BROWN);
                        top -= height; employee++;
                    }
                    text(canvas, font, "Ca làm = ca hoàn thành. Đi muộn = vào trễ từ 1 phút. Vắng = trạng thái ABSENT.", 40, 70, 8, MUTED);
                    text(canvas, font, "Không gồm ca nháp hoặc đã hủy; kỳ báo cáo tính theo ngày phân ca.", 40, 56, 8, MUTED);
                    text(canvas, font, "Coffee HRM | Trang " + document.getNumberOfPages(), 40, 32, 9, MUTED);
                }
            } while (employee < report.employees().size());
            document.save(output); return output.toByteArray();
        }
    }

    private static final Color BROWN = new Color(97, 70, 56), MUTED = new Color(100, 94, 86), CREAM = new Color(247, 242, 236);

    private static void rect(PDPageContentStream canvas, float x, float y, float width, float height, Color color) throws IOException {
        canvas.setNonStrokingColor(color); canvas.addRect(x, y, width, height); canvas.fill();
    }

    private static String safe(PDType0Font font, String value) {
        String input = Normalizer.normalize(value == null ? "" : value, Normalizer.Form.NFC).replaceAll("\\s+", " ");
        var result = new StringBuilder();
        input.codePoints().forEach(code -> {
            String character = new String(Character.toChars(code));
            try { font.encode(character); result.append(character); }
            catch (IOException | IllegalArgumentException ex) { result.append('?'); }
        });
        return result.toString();
    }

    private static void text(PDPageContentStream canvas, PDType0Font font, String value, float x, float y, float size, Color color) throws IOException {
        canvas.beginText(); canvas.setFont(font, size); canvas.setNonStrokingColor(color);
        canvas.newLineAtOffset(x, y); canvas.showText(safe(font, value)); canvas.endText();
    }

    private static List<String> wrap(PDType0Font font, String value, float size, float width) throws IOException {
        var lines = new ArrayList<String>(); var line = new StringBuilder();
        // Character wrapping also handles names without spaces and keeps rows inside the page.
        for (int code : safe(font, value).codePoints().toArray()) {
            String character = new String(Character.toChars(code));
            if (font.getStringWidth(line + character) * size / 1000 > width && !line.isEmpty()) {
                lines.add(line.toString()); line.setLength(0);
            }
            line.append(character);
        }
        if (!line.isEmpty()) lines.add(line.toString());
        return lines.isEmpty() ? List.of("") : lines;
    }
}
