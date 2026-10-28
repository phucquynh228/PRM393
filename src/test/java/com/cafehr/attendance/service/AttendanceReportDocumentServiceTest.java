package com.cafehr.attendance.service;

import com.cafehr.attendance.dto.AttendanceReportRow;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.schedule.entity.ScheduleStatus;
import com.cafehr.schedule.repository.UserScheduleRepository;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.apache.pdfbox.text.PDFTextStripper;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;
import javax.imageio.ImageIO;
import java.io.ByteArrayInputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.*;
import java.util.List;
import java.util.stream.IntStream;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class AttendanceReportDocumentServiceTest {
    UserScheduleRepository schedules = mock(UserScheduleRepository.class);
    AttendanceReportService reports = new AttendanceReportService(schedules);
    AttendanceReportDocumentService documents = new AttendanceReportDocumentService(reports);

    void fixtures() {
        var date = LocalDate.of(2026, 10, 1);
        when(schedules.findAttendanceReport(any(), any(), isNull(), isNull())).thenReturn(IntStream.rangeClosed(1, 65)
                .mapToObj(i -> new AttendanceReportRow(date, (long) i, (long) i,
                        i == 1 ? "=Nguyễn Thị Thảo Nguyên" : "Nhân viên kiểm thử Nguyễn Văn " + i,
                        "CN-01", "Thủ Đức", "Ca sáng", LocalTime.of(8, 0), LocalTime.of(16, 0),
                        ScheduleStatus.CHECKED_OUT, date.atTime(8, 10), date.atTime(16, 0), false)).toList());
    }

    @Test void excelIsNativeWorkbookWithMatchingSummaryDetailAndSafeTextCells() throws Exception {
        fixtures();
        var file = documents.export("xlsx", "month", "2026-10-01", null, null);
        assertTrue(file.filename().endsWith(".xlsx"));
        try (var book = new XSSFWorkbook(new ByteArrayInputStream(file.bytes()))) {
            assertEquals(2, book.getNumberOfSheets());
            var summary = book.getSheet("Tong hop");
            assertEquals(65, summary.getRow(5).getCell(0).getNumericCellValue());
            assertEquals(65, summary.getRow(5).getCell(1).getNumericCellValue());
            assertEquals(65, summary.getRow(5).getCell(2).getNumericCellValue());
            assertEquals(0, summary.getRow(5).getCell(3).getNumericCellValue());
            var name = summary.getRow(8).getCell(1);
            assertEquals(CellType.STRING, name.getCellType());
            assertEquals("=Nguyễn Thị Thảo Nguyên", name.getStringCellValue());
            assertEquals(65, book.getSheet("Chi tiet").getLastRowNum());
            assertEquals(470, book.getSheet("Chi tiet").getRow(1).getCell(10).getNumericCellValue());
            assertEquals(10, book.getSheet("Chi tiet").getRow(1).getCell(11).getNumericCellValue());
        }
        capture("report.xlsx", file.bytes());
    }

    @Test void pdfEmbedsVietnameseAndRepeatsTableHeadersAcrossPages() throws Exception {
        fixtures();
        var file = documents.export("pdf", "month", "2026-10-01", null, null);
        try (var document = Loader.loadPDF(file.bytes())) {
            assertTrue(document.getNumberOfPages() >= 3);
            String text = new PDFTextStripper().getText(document);
            assertTrue(text.contains("Báo cáo chấm công"));
            assertTrue(text.contains("Tháng 10/2026"));
            assertTrue(text.contains("Nguyễn Thị Thảo Nguyên"));
            assertTrue(text.contains("NV-0065"));
            var stripper = new PDFTextStripper(); stripper.setStartPage(2); stripper.setEndPage(2);
            assertTrue(stripper.getText(document).contains("Nhân viên"));
            if (Boolean.getBoolean("attendance.report.capture")) {
                var renderer = new PDFRenderer(document);
                Path dir = Path.of("target/report-preview"); Files.createDirectories(dir);
                ImageIO.write(renderer.renderImageWithDPI(0, 110), "png", dir.resolve("report-first.png").toFile());
                ImageIO.write(renderer.renderImageWithDPI(document.getNumberOfPages() - 1, 110), "png", dir.resolve("report-last.png").toFile());
            }
        }
        capture("report.pdf", file.bytes());
    }

    @Test void emptyAndUnsupportedExportsAreRejected() {
        when(schedules.findAttendanceReport(any(), any(), isNull(), isNull())).thenReturn(List.of());
        assertThrows(BusinessException.class, () -> documents.export("xlsx", "month", "2026-10-01", null, null));
        assertThrows(BusinessException.class, () -> documents.export("pdf", "month", "2026-10-01", null, null));
        assertThrows(BusinessException.class, () -> documents.export("html", "month", "2026-10-01", null, null));
    }

    void capture(String name, byte[] bytes) throws Exception {
        if (Boolean.getBoolean("attendance.report.capture")) {
            Path dir = Path.of("target/report-preview"); Files.createDirectories(dir); Files.write(dir.resolve(name), bytes);
        }
    }
}
