package com.cafehr.service;

import com.cafehr.dto.*;
import com.cafehr.entity.*;
import com.cafehr.repository.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Opt-in SQL Server integration tests. Every test's own fixtures roll back. */
@SpringBootTest(properties = {"spring.main.banner-mode=off", "spring.jpa.show-sql=false", "debug=false",
        "logging.level.org.springframework=ERROR", "logging.level.com.cafehr=ERROR", "logging.level.org.hibernate.SQL=ERROR"})
@AutoConfigureMockMvc @Transactional
@EnabledIfSystemProperty(named = "staff.integration", matches = "true")
class StaffWorkflowIntegrationTest {
    @Autowired StaffRequestService service;
    @Autowired StaffWorkspaceService workspace;
    @Autowired UserRepository users;
    @Autowired StoreRepository stores;
    @Autowired ShiftRepository shifts;
    @Autowired UserScheduleRepository schedules;
    @Autowired AttendanceRepository attendance;
    @Autowired BranchRequestRepository requests;
    @Autowired StaffNotificationRepository notifications;
    @Autowired PasswordEncoder passwords;
    @Autowired MockMvc mvc;
    Store store;
    User staff, peer, manager;
    Shift shift;

    @BeforeEach void seedIsolatedFixtures() {
        String key = UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        store = stores.save(Store.builder().code("QA-" + key).name("Chi nhánh kiểm thử nhân viên")
                .latitude(10.0).longitude(106.0).allowedRadius(200).build());
        staff = users.save(User.builder().name("Nhân viên kiểm thử").phone("S" + key)
                .password(passwords.encode("123456")).role(Role.STAFF).store(store).build());
        peer = users.save(User.builder().name("Đồng nghiệp kiểm thử").phone("P" + key)
                .password(passwords.encode("123456")).role(Role.STAFF).store(store).build());
        manager = users.save(User.builder().name("Quản lý kiểm thử").phone("M" + key)
                .password(passwords.encode("123456")).role(Role.MANAGER).store(store).build());
        store.setManager(manager); stores.saveAndFlush(store);
        shift = shifts.save(Shift.builder().name("Ca kiểm thử").startTime(LocalTime.of(7, 0)).endTime(LocalTime.of(12, 0)).build());
    }
    UserSchedule assign(User user, LocalDate date) {
        return schedules.save(UserSchedule.builder().user(user).shift(shift).date(date).status(ScheduleStatus.PENDING).build());
    }
    BranchRequestCreate body(BranchRequestType type, LocalDate day) {
        BranchRequestCreate body = new BranchRequestCreate(); body.setType(type);
        body.setStartDate(day); body.setEndDate(day); body.setReason("Kiểm thử luồng đầy đủ"); return body;
    }
    Long id(Map<String, Object> result) { return ((Number) result.get("id")).longValue(); }

    @Test void swapLeaveCorrectionAndCancellationPersistWithinOneTransaction() {
        LocalDate future = LocalDate.now().plusDays(2);
        UserSchedule source = assign(staff, future), target = assign(peer, future.plusDays(1));
        BranchRequestCreate swap = body(BranchRequestType.SHIFT_SWAP, future);
        swap.setSourceScheduleId(source.getId()); swap.setTargetScheduleId(target.getId());
        Long swapId = id(service.create(staff.getId(), swap));
        service.decide(store.getId(), swapId, BranchRequestStatus.APPROVED, "Đồng ý đổi ca");
        schedules.flush();
        assertEquals(peer.getId(), schedules.findById(source.getId()).orElseThrow().getUser().getId());
        assertEquals(staff.getId(), schedules.findById(target.getId()).orElseThrow().getUser().getId());

        UserSchedule leaveShift = assign(staff, future.plusDays(2));
        Long leaveId = id(service.create(staff.getId(), body(BranchRequestType.UNPAID_LEAVE, leaveShift.getDate())));
        service.decide(store.getId(), leaveId, BranchRequestStatus.APPROVED, "Đã duyệt nghỉ");
        assertEquals(ScheduleStatus.ON_LEAVE, leaveShift.getStatus());

        LocalDate yesterday = LocalDate.now().minusDays(1);
        UserSchedule missed = assign(staff, yesterday);
        BranchRequestCreate correction = body(BranchRequestType.ATTENDANCE_CORRECTION, yesterday);
        correction.setSourceScheduleId(missed.getId()); correction.setRequestedCheckIn(yesterday.atTime(7, 10));
        correction.setRequestedCheckOut(yesterday.atTime(11, 45));
        Long correctionId = id(service.create(staff.getId(), correction));
        service.decide(store.getId(), correctionId, BranchRequestStatus.APPROVED, "Đã kiểm tra công");
        attendance.flush();
        Attendance record = attendance.findByScheduleId(missed.getId()).orElseThrow();
        assertTrue(record.isManuallyAdjusted()); assertNull(record.getCheckInLat());
        assertEquals(275L, StaffViews.attendance(record).get("workedMinutes"));
        assertEquals(10L, StaffViews.attendance(record).get("lateMinutes"));

        Long cancelled = id(service.create(staff.getId(), body(BranchRequestType.LEAVE, future.plusDays(10))));
        service.cancel(staff.getId(), cancelled); requests.flush();
        assertEquals(BranchRequestStatus.CANCELLED, requests.findById(cancelled).orElseThrow().getStatus());
        assertEquals(4, notifications.findTop100ByUserIdOrderByCreatedAtDescIdDesc(staff.getId()).size());
    }

    @Test void endpointsEnforceRoleOwnershipAndPersistManagerAnnouncement() throws Exception {
        String from = LocalDate.now().toString(), to = LocalDate.now().plusDays(6).toString();
        mvc.perform(get("/api/staff/workspace").param("from", from).param("to", to)
                .with(user("manager").roles("MANAGER")).requestAttr("userId", manager.getId()))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/staff/workspace").param("from", from).param("to", to)
                .with(user("staff").roles("STAFF")).requestAttr("userId", staff.getId()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.profile.id").value(staff.getId()));
        mvc.perform(post("/api/manager/announcements").contentType("application/json")
                .content("{\"title\":\"Thông báo chi nhánh\",\"message\":\"Họp đội ngũ cuối tuần\"}")
                .with(user("manager").roles("MANAGER")).requestAttr("userId", manager.getId()))
                .andExpect(status().isOk());
        StaffNotification item = notifications.findTop100ByUserIdOrderByCreatedAtDescIdDesc(staff.getId()).get(0);
        assertEquals("Thông báo chi nhánh", item.getTitle());
        mvc.perform(put("/api/staff/notifications/" + item.getId() + "/read")
                .with(user("peer").roles("STAFF")).requestAttr("userId", peer.getId()))
                .andExpect(status().isBadRequest());
        assertNull(item.getReadAt());
    }

    @Test void profileAndPasswordUpdatesRetainRoleAndBranch() {
        StaffProfileUpdate body = new StaffProfileUpdate(); body.setName("Nhân viên đã cập nhật");
        body.setEmail("staff@example.com"); body.setAddress("Thủ Đức"); body.setEmergencyContact("0901234567");
        workspace.updateProfile(staff.getId(), body);
        PasswordChangeRequest password = new PasswordChangeRequest(); password.setCurrentPassword("123456");
        password.setNewPassword("new-password-123"); workspace.changePassword(staff.getId(), password);
        users.flush();
        assertEquals("Thủ Đức", staff.getAddress()); assertEquals(Role.STAFF, staff.getRole());
        assertEquals(store.getId(), staff.getStore().getId());
        assertTrue(passwords.matches("new-password-123", staff.getPassword()));
    }
}
