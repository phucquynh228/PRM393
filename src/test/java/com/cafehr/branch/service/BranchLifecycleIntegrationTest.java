package com.cafehr.branch.service;

import com.cafehr.attendance.entity.Attendance;
import com.cafehr.attendance.repository.AttendanceRepository;
import com.cafehr.branch.dto.*;
import com.cafehr.branch.entity.*;
import com.cafehr.branch.repository.StoreRepository;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.notification.repository.StaffNotificationRepository;
import com.cafehr.schedule.entity.*;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.security.JwtUtil;
import com.cafehr.staff.entity.*;
import com.cafehr.staff.repository.BranchRequestRepository;
import com.cafehr.staff.view.StaffViews;
import com.cafehr.user.entity.*;
import com.cafehr.user.repository.UserRepository;
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

@SpringBootTest(properties = {"spring.main.banner-mode=off", "spring.jpa.show-sql=false", "debug=false",
        "logging.level.org.springframework=ERROR", "logging.level.com.cafehr=ERROR", "logging.level.org.hibernate.SQL=ERROR"})
@AutoConfigureMockMvc @Transactional
@EnabledIfSystemProperty(named = "staff.integration", matches = "true")
class BranchLifecycleIntegrationTest {
    @Autowired BranchLifecycleService service;
    @Autowired StoreRepository stores;
    @Autowired UserRepository users;
    @Autowired UserScheduleRepository schedules;
    @Autowired com.cafehr.schedule.repository.ShiftRepository shifts;
    @Autowired AttendanceRepository attendance;
    @Autowired BranchRequestRepository requests;
    @Autowired StaffNotificationRepository notifications;
    @Autowired PasswordEncoder passwords;
    @Autowired JwtUtil jwt;
    @Autowired MockMvc mvc;
    Store source, target;
    User staff, peer, manager, admin;
    Shift shift;

    @BeforeEach void setup() {
        String key = UUID.randomUUID().toString().substring(0, 8);
        source = stores.save(Store.builder().code("CLOSE-" + key).name("Chi nhánh gốc " + key)
                .latitude(10.0).longitude(106.0).allowedRadius(200).maxStaff(15).build());
        target = stores.save(Store.builder().code("TARGET-" + key).name("Chi nhánh nhận " + key)
                .latitude(11.0).longitude(107.0).allowedRadius(200).maxStaff(15).build());
        String password = passwords.encode("123456");
        staff = member("S" + key, Role.STAFF, password);
        peer = member("P" + key, Role.STAFF, password);
        manager = member("M" + key, Role.MANAGER, password);
        admin = member("A" + key, Role.ADMIN, password);
        source.setManager(manager); stores.saveAndFlush(source);
        shift = shifts.save(Shift.builder().name("Ca đóng chi nhánh").startTime(LocalTime.of(8, 0)).endTime(LocalTime.of(16, 0)).build());
    }
    User member(String phone, Role role, String password) {
        return users.save(User.builder().name(phone).phone(phone).password(password).role(role).store(source).build());
    }
    UserSchedule assign(User user, int days) {
        return schedules.saveAndFlush(UserSchedule.builder().user(user).shift(shift).date(LocalDate.now().plusDays(days))
                .status(ScheduleStatus.PENDING).published(true).build());
    }
    EmployeePlacement placement(User user, EmployeePlacement.Action action, Store destination, boolean asManager) {
        EmployeePlacement p = new EmployeePlacement(); p.setUserId(user.getId()); p.setAction(action);
        p.setTargetStoreId(destination == null ? null : destination.getId()); p.setManager(asManager); return p;
    }
    EmployeePlacement transfer(User user) { return placement(user, EmployeePlacement.Action.TRANSFER, target, false); }
    BranchClosureRequest plan(EmployeePlacement... placements) {
        BranchClosureRequest body = new BranchClosureRequest(); body.setReason("Ngừng thuê mặt bằng"); body.setPlacements(List.of(placements)); return body;
    }
    BranchClosureRequest mixedPlan() {
        return plan(transfer(staff), placement(peer, EmployeePlacement.Action.INACTIVE, null, false),
                placement(manager, EmployeePlacement.Action.WAITING_TRANSFER, null, false));
    }

    @Test void closingPreservesHistoryCancelsFutureAndHandlesAllEmployees() {
        UserSchedule past = assign(staff, -2), future = assign(staff, 2);
        past.setStatus(ScheduleStatus.CHECKED_OUT);
        Attendance historical = attendance.save(Attendance.builder().user(staff).schedule(past)
                .checkInTime(past.getDate().atTime(8, 0)).checkOutTime(past.getDate().atTime(16, 0)).build());
        BranchRequest pending = requests.saveAndFlush(BranchRequest.builder().user(staff).type(BranchRequestType.LEAVE)
                .startDate(future.getDate()).endDate(future.getDate()).reason("Việc riêng").build());
        service.close(source.getId(), mixedPlan()); users.flush(); schedules.flush();
        assertEquals(StoreStatus.CLOSED, source.getStatus()); assertNull(source.getManager()); assertNotNull(source.getClosedAt());
        assertEquals(target.getId(), staff.getStore().getId()); assertEquals(EmploymentStatus.ACTIVE, staff.getEmploymentStatus());
        assertEquals(EmploymentStatus.INACTIVE, peer.getEmploymentStatus()); assertNull(peer.getStore());
        assertEquals(EmploymentStatus.WAITING_TRANSFER, manager.getEmploymentStatus()); assertEquals(Role.STAFF, manager.getRole());
        assertNull(admin.getStore()); assertEquals(Role.ADMIN, admin.getRole());
        assertEquals(ScheduleStatus.CANCELLED, future.getStatus());
        assertEquals(BranchRequestStatus.CANCELLED, pending.getStatus()); assertEquals(source.getId(), pending.getStore().getId());
        assertEquals(source.getId(), past.getStore().getId()); assertEquals(source.getName(), StaffViews.attendance(historical).get("storeName"));
        assertEquals(source.getId(), StaffViews.schedule(past).get("storeId"));
        assertEquals(2, schedules.findByStoreIdOrderByDateAscShiftStartTimeAsc(source.getId()).size());
        assertTrue(schedules.findByStoreIdOrderByDateAscShiftStartTimeAsc(target.getId()).isEmpty());
        assertFalse(notifications.findTop100ByUserIdOrderByCreatedAtDescIdDesc(staff.getId()).isEmpty());
        assertFalse(service.canDelete(source.getId()));
    }

    @Test void openAttendanceBlocksClosureWithoutChangingPeopleOrSchedules() {
        UserSchedule schedule = assign(staff, 0); schedule.setStatus(ScheduleStatus.CHECKED_IN);
        attendance.saveAndFlush(Attendance.builder().user(staff).schedule(schedule).checkInTime(LocalDateTime.now().minusMinutes(15)).build());
        assertThrows(BusinessException.class, () -> service.close(source.getId(), mixedPlan()));
        assertEquals(StoreStatus.ACTIVE, source.getStatus()); assertEquals(source.getId(), staff.getStore().getId());
        assertEquals(ScheduleStatus.CHECKED_IN, schedule.getStatus());
        assertTrue(((Number) service.preview(source.getId()).get("openAttendances")).longValue() > 0);
    }

    @Test void capacityChecksWholeIncomingGroupBeforeCancellingSchedules() {
        target.setMaxStaff(2); stores.flush();
        UserSchedule future = assign(staff, 2);
        assertThrows(BusinessException.class, () -> service.close(source.getId(), plan(transfer(staff), transfer(peer), transfer(manager))));
        assertEquals(StoreStatus.ACTIVE, source.getStatus()); assertEquals(ScheduleStatus.PENDING, future.getStatus());
        assertEquals(source.getId(), staff.getStore().getId());
    }

    @Test void everyEmployeeMustBeHandledExactlyOnce() {
        assertThrows(BusinessException.class, () -> service.close(source.getId(), plan(transfer(staff), transfer(peer))));
        assertThrows(BusinessException.class, () -> service.close(source.getId(), plan(transfer(staff), transfer(staff), transfer(manager))));
        assertEquals(StoreStatus.ACTIVE, source.getStatus());
    }

    @Test void waitingEmployeeCanBePlacedLaterAndManagerCanBeReappointed() {
        service.close(source.getId(), mixedPlan());
        EmployeePlacement placement = placement(manager, EmployeePlacement.Action.TRANSFER, target, true);
        service.place(manager.getId(), placement); users.flush();
        assertEquals(EmploymentStatus.ACTIVE, manager.getEmploymentStatus()); assertEquals(Role.MANAGER, manager.getRole());
        assertEquals(manager.getId(), target.getManager().getId()); assertNull(source.getManager());
    }

    @Test void inactiveTokenAndOldManagerRoleStopWorkingImmediately() throws Exception {
        String staffToken = jwt.generateToken(peer.getPhone(), peer.getId(), "STAFF");
        String managerToken = jwt.generateToken(manager.getPhone(), manager.getId(), "MANAGER");
        service.close(source.getId(), mixedPlan()); users.flush();
        mvc.perform(get("/api/staff/workspace").param("from", LocalDate.now().toString()).param("to", LocalDate.now().toString())
                .header("Authorization", "Bearer " + staffToken)).andExpect(status().isForbidden());
        mvc.perform(get("/api/manager/branch").header("Authorization", "Bearer " + managerToken)).andExpect(status().isForbidden());
        mvc.perform(post("/api/auth/login").contentType("application/json").content("{\"phone\":\"" + peer.getPhone()
                + "\",\"password\":\"123456\",\"deviceId\":\"qa\"}")).andExpect(status().isForbidden());
    }

    @Test void onlyNeverUsedEmptyBranchCanBePermanentlyDeleted() {
        UserSchedule historical = assign(staff, -2);
        service.close(source.getId(), mixedPlan());
        assertThrows(BusinessException.class, () -> service.deleteUnused(source.getId()));
        assertTrue(stores.existsById(source.getId())); assertTrue(schedules.existsById(historical.getId()));
        Store empty = stores.saveAndFlush(Store.builder().code("EMPTY-" + UUID.randomUUID().toString().substring(0, 8)).name("Tạo nhầm")
                .latitude(10.0).longitude(106.0).allowedRadius(200).build());
        Long emptyId = empty.getId(); service.deleteUnused(emptyId); stores.flush(); assertFalse(stores.existsById(emptyId));
    }

    @Test void managerCannotCloseBranchAndEditEndpointCannotBypassClosure() throws Exception {
        mvc.perform(post("/api/admin/stores/" + source.getId() + "/close").contentType("application/json")
                .content("{\"reason\":\"Thử quyền\",\"placements\":[]}").with(user("manager").roles("MANAGER")))
                .andExpect(status().isForbidden());
        mvc.perform(put("/api/admin/stores/" + source.getId()).with(user("admin").roles("ADMIN"))
                .contentType("application/json").content("{\"name\":\"Chi nhánh\",\"latitude\":10,\"longitude\":106,\"allowedRadius\":200,\"status\":\"CLOSED\"}"))
                .andExpect(status().isBadRequest());
        assertEquals(StoreStatus.ACTIVE, source.getStatus());
    }

    @Test void oldUserUpdateEndpointAlsoTransfersWithoutRewritingHistory() throws Exception {
        UserSchedule historical = assign(staff, -2), future = assign(staff, 2);
        mvc.perform(put("/api/admin/users/" + staff.getId()).with(user("admin").roles("ADMIN"))
                .contentType("application/json").content("{\"storeId\":" + target.getId() + "}"))
                .andExpect(status().isOk());
        assertEquals(target.getId(), staff.getStore().getId());
        assertEquals(source.getId(), historical.getStore().getId()); assertEquals(ScheduleStatus.CANCELLED, future.getStatus());
    }

    @Test void receivingManagerCanReassignSameShiftAfterOldBranchCancelledIt() throws Exception {
        UserSchedule cancelled = assign(staff, 2);
        service.close(source.getId(), mixedPlan());
        service.place(manager.getId(), placement(manager, EmployeePlacement.Action.TRANSFER, target, true));
        mvc.perform(post("/api/manager/schedules").with(user(manager.getPhone()).roles("MANAGER"))
                .requestAttr("userId", manager.getId()).contentType("application/json")
                .content("{\"userId\":" + staff.getId() + ",\"shiftId\":" + shift.getId() + ",\"date\":\"" + cancelled.getDate() + "\",\"published\":true}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.storeId").value(target.getId()));
        assertEquals(ScheduleStatus.CANCELLED, cancelled.getStatus());
        assertEquals(2, schedules.findByUserIdAndDate(staff.getId(), cancelled.getDate()).size());
    }
}
