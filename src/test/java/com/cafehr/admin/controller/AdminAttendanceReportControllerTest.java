package com.cafehr.admin.controller;

import com.cafehr.attendance.service.AttendanceReportService;
import com.cafehr.attendance.service.AttendanceReportDocumentService;
import com.cafehr.attendance.dto.AttendanceReportSummary;
import java.time.LocalDate;
import java.util.List;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.config.SecurityConfig;
import com.cafehr.security.CustomUserDetailsService;
import com.cafehr.security.JwtAuthenticationFilter;
import com.cafehr.security.JwtUtil;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.MockMvc;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(value = AdminAttendanceReportController.class, properties = {"debug=false", "logging.level.org.springframework=ERROR", "logging.level.com.cafehr=ERROR"})
@Import({SecurityConfig.class, JwtAuthenticationFilter.class})
class AdminAttendanceReportControllerTest {
    @Autowired MockMvc mvc;
    @MockBean AttendanceReportService reports;
    @MockBean AttendanceReportDocumentService documents;
    @MockBean CustomUserDetailsService users;
    @MockBean JwtUtil jwt;

    @Test void adminDownloadsAttachmentWithFilters() throws Exception {
        when(reports.export("month", "2024-02-01", 2L, 3L))
                .thenReturn(new AttendanceReportService.ReportFile("report.csv", new byte[]{1, 2, 3}));
        mvc.perform(get("/api/admin/attendance/export").with(user("admin").roles("ADMIN"))
                        .param("period", "month").param("date", "2024-02-01")
                        .param("userId", "2").param("storeId", "3"))
                .andExpect(status().isOk()).andExpect(content().contentType("text/csv;charset=UTF-8"))
                .andExpect(header().string("Content-Disposition", "attachment; filename=\"report.csv\""))
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(content().bytes(new byte[]{1, 2, 3}));
    }

    @Test void employeeManagerAndAnonymousCannotExport() throws Exception {
        for (String role : new String[]{"STAFF", "MANAGER"}) {
            mvc.perform(get("/api/admin/attendance/export").param("date", "2024-02-01")
                    .with(user("employee").roles(role))).andExpect(status().isForbidden());
        }
        mvc.perform(get("/api/admin/attendance/export").param("date", "2024-02-01"))
                .andExpect(status().isForbidden());
        verifyNoInteractions(reports);
    }

    @Test void validationUsesJsonErrorInsteadOfCsv() throws Exception {
        when(reports.export("day", "invalid", null, null)).thenThrow(new BusinessException("Ngày không hợp lệ"));
        mvc.perform(get("/api/admin/attendance/export").with(user("admin").roles("ADMIN"))
                .param("date", "invalid")).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Ngày không hợp lệ"));
    }

    @Test void nativeFormatsHaveCorrectMimeTypesAndRemainAdminOnly() throws Exception {
        for (String format : new String[]{"xlsx", "pdf"}) {
            when(documents.export(format, "month", "2026-10-01", null, null))
                    .thenReturn(new AttendanceReportService.ReportFile("report." + format, new byte[]{1, 2}));
            mvc.perform(get("/api/admin/attendance/export").with(user("admin").roles("ADMIN"))
                            .param("period", "month").param("date", "2026-10-01").param("format", format))
                    .andExpect(status().isOk()).andExpect(content().contentTypeCompatibleWith(format.equals("pdf") ? "application/pdf"
                            : "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"));
            mvc.perform(get("/api/admin/attendance/export").with(user("staff").roles("STAFF"))
                    .param("format", format)).andExpect(status().isForbidden());
        }
        mvc.perform(get("/api/admin/attendance/report").with(user("manager").roles("MANAGER")))
                .andExpect(status().isForbidden());
    }

    @Test void adminCanPreviewEmptySummaryWithoutDownloadingAFile() throws Exception {
        var summary = new AttendanceReportSummary("month", LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 31),
                "Tất cả nhân viên | Tất cả chi nhánh", 0, 0, 0, 0, List.of());
        when(reports.snapshot("month", "2026-10-01", null, null))
                .thenReturn(new AttendanceReportService.Snapshot(summary, List.of(), "report"));
        mvc.perform(get("/api/admin/attendance/report").with(user("admin").roles("ADMIN"))
                        .param("date", "2026-10-01"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.employeeCount").value(0))
                .andExpect(jsonPath("$.data.employees").isEmpty())
                .andExpect(header().string("Cache-Control", "no-store"));
        verifyNoInteractions(documents);
    }
}
