package com.cafehr.schedule.service;

import com.cafehr.branch.controller.BranchManagerController;
import com.cafehr.branch.entity.*;
import com.cafehr.branch.repository.StoreRepository;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.schedule.dto.RosterRequests;
import com.cafehr.schedule.entity.*;
import com.cafehr.schedule.repository.*;
import com.cafehr.staff.entity.*;
import com.cafehr.staff.repository.BranchRequestRepository;
import com.cafehr.notification.repository.StaffNotificationRepository;
import com.cafehr.user.entity.*;
import com.cafehr.user.repository.UserRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.test.context.support.WithMockUser;
import java.time.*;
import java.time.temporal.TemporalAdjusters;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties = {"spring.main.banner-mode=off", "spring.jpa.show-sql=false", "debug=false",
        "logging.level.org.springframework=ERROR", "logging.level.com.cafehr=ERROR", "logging.level.org.hibernate.SQL=ERROR"})
@AutoConfigureMockMvc @Transactional @WithMockUser(roles = "MANAGER")
@EnabledIfSystemProperty(named = "roster.integration", matches = "true")
class FixedRosterIntegrationTest {
    @Autowired FixedRosterService roster;
    @Autowired AdminRosterService transfers;
    @Autowired com.cafehr.attendance.service.AttendanceService attendanceService;
    @Autowired BranchManagerController controller;
    @Autowired UserRepository users;
    @Autowired StoreRepository stores;
    @Autowired ShiftRepository shifts;
    @Autowired UserScheduleRepository schedules;
    @Autowired BranchRequestRepository requests;
    @Autowired StaffNotificationRepository notifications;
    @Autowired EntityManager em;
    @Autowired MockMvc mvc;
    Store store, other;
    User manager, staff, peer, outsider;
    Shift morning, afternoon, evening;
    LocalDate monday = LocalDate.now().with(TemporalAdjusters.next(DayOfWeek.MONDAY));

    @BeforeEach void fixtures() {
        String key = UUID.randomUUID().toString().substring(0, 8);
        store = stores.save(Store.builder().code("RO-" + key).name("Chi nhánh phân ca")
                .latitude(10.0).longitude(106.0).allowedRadius(200).build());
        other = stores.save(Store.builder().code("RX-" + key).name("Chi nhánh khác")
                .latitude(10.0).longitude(106.0).allowedRadius(200).build());
        manager = member("M" + key, Role.MANAGER, store);
        staff = member("S" + key, Role.STAFF, store);
        peer = member("P" + key, Role.STAFF, store);
        outsider = member("O" + key, Role.STAFF, other);
        store.setManager(manager); stores.saveAndFlush(store);
        morning = shift("Ca sáng", 7, 12); afternoon = shift("Ca chiều", 12, 17); evening = shift("Ca tối", 17, 22);
        roster.saveSettings(manager.getId(), new RosterRequests.Settings(List.of(
                new RosterRequests.SlotPlan(ShiftSlot.MORNING, morning.getId(), 2),
                new RosterRequests.SlotPlan(ShiftSlot.AFTERNOON, afternoon.getId(), 2),
                new RosterRequests.SlotPlan(ShiftSlot.EVENING, evening.getId(), 4))));
        stores.flush();
    }
    User member(String phone, Role role, Store branch) {
        return users.save(User.builder().name(phone).phone(phone).password("test-password").role(role).store(branch).build());
    }
    Shift shift(String name, int start, int end) {
        return shifts.save(Shift.builder().name(name).startTime(LocalTime.of(start, 0)).endTime(LocalTime.of(end, 0)).build());
    }
    MockHttpServletRequest request() {
        var request = new MockHttpServletRequest(); request.setAttribute("userId", manager.getId()); return request;
    }
    List<UserSchedule> week() { return schedules.findByStoreIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(store.getId(), monday, monday.plusDays(6)); }

    @Test void persistedPreferencesGenerateOnceAndOnlyPublishSendsNotifications() {
        staff.getFixedRoster().addAll(List.of(new FixedRosterEntry(1, ShiftSlot.EVENING), new FixedRosterEntry(2, ShiftSlot.EVENING)));
        users.saveAndFlush(staff); stores.flush();
        var result = roster.generate(manager.getId(), monday);
        assertEquals(2, result.get("created"));
        assertTrue(week().stream().allMatch(s -> !s.isPublished() && s.getShiftSlot() == ShiftSlot.EVENING));
        assertTrue(notifications.findTop100ByUserIdOrderByCreatedAtDescIdDesc(staff.getId()).isEmpty());
        assertEquals(0, roster.generate(manager.getId(), monday).get("created"));
        assertEquals(2, roster.generate(manager.getId(), monday).get("existing"));
        assertEquals(2, controller.publishRange(request(), monday, monday.plusDays(6)).getBody().getData());
        assertTrue(week().stream().allMatch(UserSchedule::isPublished));
        assertEquals(2, notifications.findTop100ByUserIdOrderByCreatedAtDescIdDesc(staff.getId()).size());
        em.flush(); em.clear();
        assertEquals(2, users.findById(staff.getId()).orElseThrow().getFixedRoster().size());
        assertEquals(4, roster.settings(manager.getId()).get(2).get("requiredStaff"));
    }

    @Test void deletedGeneratedDraftIsNotRestoredAndLeaveIsReported() {
        staff.getFixedRoster().add(new FixedRosterEntry(1, ShiftSlot.EVENING));
        peer.getFixedRoster().add(new FixedRosterEntry(1, ShiftSlot.EVENING)); users.flush();
        requests.saveAndFlush(BranchRequest.builder().user(peer).store(store).type(BranchRequestType.LEAVE)
                .status(BranchRequestStatus.APPROVED).startDate(monday).endDate(monday).reason("Nghỉ đã duyệt").build());
        var result = roster.generate(manager.getId(), monday);
        assertEquals(1, result.get("created")); assertEquals(1, ((List<?>) result.get("skipped")).size());
        var draft = week().get(0); controller.deleteSchedule(request(), draft.getId()); schedules.flush();
        assertEquals(ScheduleStatus.CANCELLED, draft.getStatus());
        assertEquals(0, roster.generate(manager.getId(), monday).get("created"));
        assertEquals(0, controller.publishRange(request(), monday, monday.plusDays(6)).getBody().getData());
    }

    @Test void batchAddsMultiplePeopleAndIsIdempotent() {
        var body = new RosterRequests.Batch(monday, ShiftSlot.MORNING, List.of(staff.getId(), peer.getId()));
        assertEquals(2, roster.assign(manager.getId(), body).get("created"));
        assertEquals(2, week().size()); assertTrue(week().stream().noneMatch(UserSchedule::isPublished));
        assertEquals(0, roster.assign(manager.getId(), body).get("created"));
    }

    @Test void invalidMemberPreventsTheWholeBatch() {
        assertThrows(BusinessException.class, () -> roster.assign(manager.getId(), new RosterRequests.Batch(monday,
                ShiftSlot.MORNING, List.of(staff.getId(), outsider.getId()))));
        assertTrue(week().isEmpty());
    }

    @Test void overlappingDefaultsAreSkippedWithoutDuplicatingTime() {
        staff.getFixedRoster().addAll(List.of(new FixedRosterEntry(1, ShiftSlot.MORNING), new FixedRosterEntry(1, ShiftSlot.EVENING)));
        users.flush();
        Shift overlapping = shift("Ca dài", 10, 20);
        roster.saveSettings(manager.getId(), new RosterRequests.Settings(List.of(
                new RosterRequests.SlotPlan(ShiftSlot.MORNING, morning.getId(), 2),
                new RosterRequests.SlotPlan(ShiftSlot.AFTERNOON, afternoon.getId(), 2),
                new RosterRequests.SlotPlan(ShiftSlot.EVENING, overlapping.getId(), 4))));
        stores.flush();
        var result = roster.generate(manager.getId(), monday);
        assertEquals(1, result.get("created")); assertEquals(1, ((List<?>) result.get("skipped")).size());
        assertEquals(1, week().size());
    }

    @Test void apiValidatesPreferencesScopeAndRoles() throws Exception {
        mvc.perform(put("/api/manager/staff/" + staff.getId()).with(user("manager").roles("MANAGER"))
                        .requestAttr("userId", manager.getId()).contentType("application/json")
                        .content("{\"name\":\"Nhân viên tối\",\"phone\":\"0901234567\",\"fixedRoster\":[{\"dayOfWeek\":1,\"slot\":\"EVENING\"}]}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.fixedRoster[0].slot").value("EVENING"));
        mvc.perform(put("/api/manager/staff/" + staff.getId()).with(user("manager").roles("MANAGER"))
                        .requestAttr("userId", manager.getId()).contentType("application/json")
                        .content("{\"name\":\"Nhân viên\",\"phone\":\"0901234567\",\"fixedRoster\":[{\"dayOfWeek\":8,\"slot\":\"EVENING\"}]}"))
                .andExpect(status().isBadRequest());
        mvc.perform(get("/api/manager/roster/settings").with(user("staff").roles("STAFF")))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/manager/schedules/batch").with(user("admin").roles("ADMIN"))
                        .contentType("application/json").content("{}"))
                .andExpect(status().isForbidden());
    }

    @Test void adminTransferMovesDraftBetweenBranchViewsAndReceivingManagerCanPublish() throws Exception {
        roster.assign(manager.getId(), new RosterRequests.Batch(monday, ShiftSlot.MORNING, List.of(staff.getId())));
        var assignment = week().get(0);
        mvc.perform(put("/api/admin/schedules/" + assignment.getId() + "/transfer").with(user("admin").roles("ADMIN"))
                        .contentType("application/json").content("{\"sourceStoreId\":" + store.getId() + ",\"targetStoreId\":" + other.getId() + "}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.storeId").value(other.getId()))
                .andExpect(jsonPath("$.data.published").value(false)).andExpect(jsonPath("$.data.temporaryTransfer").value(true));
        em.flush(); em.clear();
        assertTrue(week().isEmpty());
        var received = schedules.findByStoreIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(other.getId(), monday, monday.plusDays(6));
        assertEquals(1, received.size()); assertEquals(store.getId(), users.findById(staff.getId()).orElseThrow().getStore().getId());
        var receivingManager = member("RM" + UUID.randomUUID().toString().substring(0, 8), Role.MANAGER, other);
        mvc.perform(post("/api/manager/schedules/" + assignment.getId() + "/publish").with(user("receiver").roles("MANAGER"))
                        .requestAttr("userId", receivingManager.getId()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.published").value(true));
        assertEquals(1, notifications.findTop100ByUserIdOrderByCreatedAtDescIdDesc(staff.getId()).size());
        mvc.perform(get("/api/admin/roster/settings").with(user("admin").roles("ADMIN")).param("storeId", store.getId().toString()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data[0].plans[2].requiredStaff").value(4));
        mvc.perform(put("/api/admin/schedules/" + assignment.getId() + "/transfer").with(user("manager").roles("MANAGER"))
                        .contentType("application/json").content("{\"sourceStoreId\":" + other.getId() + ",\"targetStoreId\":" + store.getId() + "}"))
                .andExpect(status().isForbidden());
    }

    @Test void transferredShiftChecksGpsAtReceivingBranchAndNormalForeignShiftIsRejected() {
        other.setLatitude(11.0); other.setLongitude(107.0); stores.flush();
        var assignment = schedules.saveAndFlush(UserSchedule.builder().user(staff).store(other)
                .temporaryTransfer(true).shift(morning).date(LocalDate.now()).status(ScheduleStatus.PENDING).build());
        var body = new com.cafehr.attendance.dto.CheckInRequest();
        body.setScheduleId(assignment.getId()); body.setLat(store.getLatitude()); body.setLng(store.getLongitude());
        assertThrows(com.cafehr.common.exception.OutOfRangeException.class, () -> attendanceService.checkIn(staff.getId(), body));
        body.setLat(other.getLatitude()); body.setLng(other.getLongitude());
        assignment.setTemporaryTransfer(false);
        assertThrows(BusinessException.class, () -> attendanceService.checkIn(staff.getId(), body));
        assignment.setTemporaryTransfer(true);
        var checkedIn = attendanceService.checkIn(staff.getId(), body);
        assertEquals(other.getId(), checkedIn.getStoreId());
        assertEquals(store.getId(), staff.getStore().getId());
    }
}
