package com.cafehr.admin.controller;

import com.cafehr.attendance.service.AttendanceReportService;
import com.cafehr.attendance.service.AttendanceReportDocumentService;
import com.cafehr.attendance.dto.AttendanceReportSummary;
import com.cafehr.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/attendance")
@RequiredArgsConstructor
public class AdminAttendanceReportController {
    private final AttendanceReportService reports;
    private final AttendanceReportDocumentService documents;

    @GetMapping("/report")
    public ResponseEntity<ApiResponse<AttendanceReportSummary>> summary(
            @RequestParam(defaultValue = "month") String period,
            @RequestParam(defaultValue = "") String date,
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) Long storeId) {
        return ResponseEntity.ok().header(HttpHeaders.CACHE_CONTROL, "no-store")
                .body(ApiResponse.ok(reports.snapshot(period, date, userId, storeId).summary()));
    }

    @GetMapping("/export")
    public ResponseEntity<byte[]> export(
            @RequestParam(defaultValue = "day") String period,
            @RequestParam(defaultValue = "") String date,
            @RequestParam(defaultValue = "csv") String format,
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) Long storeId) {
        var file = format.equals("csv") ? reports.export(period, date, userId, storeId)
                : documents.export(format, period, date, userId, storeId);
        String contentType = switch (format) {
            case "xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            case "pdf" -> "application/pdf";
            default -> "text/csv;charset=UTF-8";
        };
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(contentType))
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment().filename(file.filename()).build().toString())
                .header(HttpHeaders.CACHE_CONTROL, "no-store")
                .body(file.bytes());
    }
}
