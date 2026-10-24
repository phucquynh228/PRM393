package com.cafehr.staff.service;

import com.cafehr.attendance.entity.Attendance;
import com.cafehr.attendance.repository.AttendanceRepository;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.notification.entity.StaffNotification;
import com.cafehr.notification.repository.StaffNotificationRepository;
import com.cafehr.schedule.entity.ScheduleStatus;
import com.cafehr.schedule.entity.UserSchedule;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.staff.dto.PasswordChangeRequest;
import com.cafehr.staff.dto.StaffProfileUpdate;
import com.cafehr.staff.repository.BranchRequestRepository;
import com.cafehr.staff.view.StaffViews;
import com.cafehr.user.entity.Role;
import com.cafehr.user.entity.User;
import com.cafehr.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.time.temporal.TemporalAdjusters;
import java.util.*;
import static com.cafehr.staff.view.StaffViews.*;

@Service @RequiredArgsConstructor
public class StaffWorkspaceService {
    private final UserRepository users;
    private final UserScheduleRepository schedules;
    private final AttendanceRepository attendance;
    private final BranchRequestRepository requests;
    private final StaffNotificationRepository notifications;
    private final PasswordEncoder passwords;

    public User staff(Long userId) {
        return users.findById(userId).filter(u -> u.getRole() == Role.STAFF)
                .orElseThrow(() -> new BusinessException("Không tìm thấy tài khoản nhân viên"));
    }

    @Transactional(readOnly = true)
    public Map<String, Object> workspace(Long userId, LocalDate from, LocalDate to) {
        User user = staff(userId);
        if (from == null || to == null || to.isBefore(from) || Duration.between(from.atStartOfDay(), to.atStartOfDay()).toDays() > 62) {
            throw new BusinessException("Khoảng lịch không hợp lệ (tối đa 63 ngày)");
        }
        LocalDate today = LocalDate.now();
        LocalDate monday = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
        List<Attendance> history = attendance.findByUserIdOrderByCheckInTimeDesc(userId);
        List<UserSchedule> todaySchedules = new ArrayList<>(schedules.findByUserIdAndDateAndPublishedTrue(userId, today));
        history.stream().filter(a -> a.getCheckOutTime() == null)
                .map(Attendance::getSchedule).filter(s -> !s.getDate().equals(today)).forEach(todaySchedules::add);
        long workedMinutes = history.stream().filter(a -> a.getCheckOutTime() != null).mapToLong(a -> {
            LocalDateTime start = a.getCheckInTime().isAfter(monday.atStartOfDay()) ? a.getCheckInTime() : monday.atStartOfDay();
            LocalDateTime end = a.getCheckOutTime().isBefore(monday.plusWeeks(1).atStartOfDay())
                    ? a.getCheckOutTime() : monday.plusWeeks(1).atStartOfDay();
            return Math.max(0, Duration.between(start, end).toMinutes());
        }).sum();
        List<UserSchedule> week = schedules.findByUserIdAndDateBetweenAndPublishedTrueOrderByDateAscShiftStartTimeAsc(
                userId, monday, monday.plusDays(6));
        long planned = week.stream().filter(s -> s.getStatus() != ScheduleStatus.ON_LEAVE)
                .mapToLong(s -> Duration.between(start(s), end(s)).toMinutes()).sum();
        return row("profile", profile(user), "today", todaySchedules.stream().map(StaffViews::schedule).toList(),
                "schedules", schedules.findByUserIdAndDateBetweenAndPublishedTrueOrderByDateAscShiftStartTimeAsc(userId, from, to)
                        .stream().map(StaffViews::schedule).toList(),
                "attendance", history.stream().map(StaffViews::attendance).toList(),
                "requests", requests.findByUserIdOrderByCreatedAtDesc(userId).stream().map(StaffViews::request).toList(),
                "notifications", notifications.findTop100ByUserIdOrderByCreatedAtDescIdDesc(userId).stream().map(StaffViews::notification).toList(),
                "weekWorkedMinutes", workedMinutes, "weekPlannedMinutes", planned, "weekFrom", monday, "serverTime", LocalDateTime.now());
    }

    @Transactional(readOnly = true)
    public Map<String, Object> options(Long userId) {
        User user = staff(userId);
        LocalDate today = LocalDate.now();
        List<UserSchedule> mine = schedules.findByUserIdAndDateBetweenAndPublishedTrueOrderByDateAscShiftStartTimeAsc(
                userId, today.minusDays(30), today.plusDays(365));
        List<UserSchedule> peers = user.getStore() == null ? List.of()
                : schedules.findByUserStoreIdAndDateBetweenAndPublishedTrueOrderByDateAscShiftStartTimeAsc(
                        user.getStore().getId(), today, today.plusDays(365)).stream()
                .filter(s -> s.getUser().getRole() == Role.STAFF && !s.getUser().getId().equals(userId)
                        && s.getStatus() == ScheduleStatus.PENDING && start(s).isAfter(LocalDateTime.now())).toList();
        return row("mine", mine.stream().map(StaffViews::schedule).toList(), "peers", peers.stream().map(StaffViews::schedule).toList());
    }

    @Transactional
    public Map<String, Object> updateProfile(Long userId, StaffProfileUpdate body) {
        User user = staff(userId);
        user.setName(body.getName().trim());
        user.setEmail(clean(body.getEmail()));
        user.setEmergencyContact(clean(body.getEmergencyContact()));
        user.setAddress(clean(body.getAddress()));
        return profile(user);
    }

    @Transactional
    public void changePassword(Long userId, PasswordChangeRequest body) {
        User user = staff(userId);
        if (!passwords.matches(body.getCurrentPassword(), user.getPassword())) {
            throw new BusinessException("Mật khẩu hiện tại không đúng");
        }
        if (passwords.matches(body.getNewPassword(), user.getPassword())) {
            throw new BusinessException("Mật khẩu mới phải khác mật khẩu hiện tại");
        }
        if (body.getNewPassword().getBytes(java.nio.charset.StandardCharsets.UTF_8).length > 72) {
            throw new BusinessException("Mật khẩu tối đa 72 byte UTF-8");
        }
        user.setPassword(passwords.encode(body.getNewPassword()));
    }

    @Transactional
    public void markRead(Long userId, Long id) {
        staff(userId);
        StaffNotification item = notifications.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new BusinessException("Không tìm thấy thông báo của bạn"));
        item.setReadAt(LocalDateTime.now());
    }

    @Transactional
    public void markAllRead(Long userId) {
        staff(userId);
        notifications.findTop100ByUserIdOrderByCreatedAtDescIdDesc(userId)
                .stream().filter(n -> n.getReadAt() == null).forEach(n -> n.setReadAt(LocalDateTime.now()));
    }

    private String clean(String value) { return value == null || value.isBlank() ? null : value.trim(); }
}
