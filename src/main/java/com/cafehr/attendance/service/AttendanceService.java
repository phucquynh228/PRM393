package com.cafehr.attendance.service;

import com.cafehr.attendance.dto.AttendanceResponse;
import com.cafehr.attendance.dto.CheckInRequest;
import com.cafehr.attendance.entity.Attendance;
import com.cafehr.attendance.repository.AttendanceRepository;
import com.cafehr.branch.entity.Store;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.common.exception.OutOfRangeException;
import com.cafehr.schedule.entity.ScheduleStatus;
import com.cafehr.schedule.entity.UserSchedule;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.staff.view.StaffViews;
import com.cafehr.user.entity.User;
import com.cafehr.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Service xử lý logic chấm công GPS.
 *
 * Check-in flow:
 * 1. Lấy userId từ JWT (SecurityContext).
 * 2. Tìm UserSchedule hôm nay của user.
 * 3. Lấy tọa độ Store mà user thuộc về.
 * 4. Tính khoảng cách bằng Haversine giữa tọa độ user gửi lên và tọa độ Store.
 * 5. Nếu khoảng cách > allowedRadius -> throw OutOfRangeException (HTTP 400).
 * 6. Lưu bản ghi Attendance.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AttendanceService {

    private final AttendanceRepository attendanceRepository;
    private final UserRepository userRepository;
    private final UserScheduleRepository userScheduleRepository;
    private final EntityManager entityManager;

    /** Bán kính Trái Đất tính bằng mét */
    private static final double EARTH_RADIUS_METERS = 6_371_000.0;

    // ========================= CHECK-IN =========================

    /**
     * Xử lý check-in chấm công.
     *
     * @param userId ID của user (lấy từ JWT)
     * @param request chứa lat, lng, và scheduleId (optional)
     * @return AttendanceResponse
     */
    @Transactional
    public AttendanceResponse checkIn(Long userId, CheckInRequest request) {
        // 1. Lấy user kèm store
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException("User không tồn tại"));

        Store store = user.getStore();
        if (store == null) {
            throw new BusinessException("User chưa được gán vào cửa hàng nào");
        }

        // 2. Tìm schedule
        UserSchedule schedule;
        if (request.getScheduleId() != null) {
            schedule = userScheduleRepository.findLockedById(request.getScheduleId())
                    .orElseThrow(() -> new BusinessException("Không tìm thấy lịch làm việc với id: " + request.getScheduleId()));

            // Verify schedule thuộc về user này
            if (!schedule.getUser().getId().equals(userId)) {
                throw new BusinessException("Lịch làm việc không thuộc về bạn");
            }
            if (!schedule.isPublished()) {
                throw new BusinessException("Lịch làm việc chưa được công bố");
            }
        } else {
            // Tự tìm schedule hôm nay
            schedule = userScheduleRepository
                    .findFirstByUserIdAndDateAndPublishedTrueOrderByIdAsc(userId, LocalDate.now())
                    .orElseThrow(() -> new BusinessException("Bạn không có ca làm việc hôm nay"));
        }

        // 3. Kiểm tra đã check-in chưa
        boolean overnight = schedule.getDate().equals(LocalDate.now().minusDays(1))
                && !schedule.getShift().getEndTime().isAfter(schedule.getShift().getStartTime())
                && LocalDateTime.now().isBefore(StaffViews.end(schedule));
        if (!schedule.getDate().equals(LocalDate.now()) && !overnight) {
            throw new BusinessException("Chỉ được check-in ca làm hôm nay");
        }
        if (schedule.getStatus() != ScheduleStatus.PENDING
                || attendanceRepository.findByScheduleId(schedule.getId()).isPresent()) {
            throw new BusinessException("Ca đã chấm công hoặc không thể chấm công");
        }

        // 4. Kiểm tra khoảng cách GPS bằng Haversine
        double distance = calculateHaversineDistance(
                request.getLat(), request.getLng(),
                store.getLatitude(), store.getLongitude()
        );

        log.info("GPS check-in: user={}, distance={}m, allowedRadius={}m",
                userId, String.format("%.2f", distance), store.getAllowedRadius());

        if (distance > store.getAllowedRadius()) {
            throw new OutOfRangeException(
                    String.format("Bạn đang ở ngoài phạm vi chấm công. Khoảng cách: %.0fm, cho phép: %dm",
                            distance, store.getAllowedRadius())
            );
        }

        // 5. Tạo bản ghi attendance
        Attendance attendance = Attendance.builder()
                .user(user)
                .schedule(schedule)
                .checkInTime(LocalDateTime.now())
                .checkInLat(request.getLat())
                .checkInLng(request.getLng())
                .build();

        attendance = attendanceRepository.save(attendance);

        // 6. Cập nhật trạng thái schedule
        schedule.setStatus(ScheduleStatus.CHECKED_IN);
        userScheduleRepository.save(schedule);

        log.info("Check-in thành công: user={}, schedule={}, attendance={}",
                userId, schedule.getId(), attendance.getId());

        return toResponse(attendance);
    }

    // ========================= CHECK-OUT =========================

    /**
     * Xử lý check-out chấm công.
     *
     * @param userId       ID của user (lấy từ JWT)
     * @param attendanceId ID của bản ghi attendance
     * @return AttendanceResponse
     */
    @Transactional
    public AttendanceResponse checkOut(Long userId, Long attendanceId) {
        Attendance attendance = attendanceRepository.findById(attendanceId)
                .orElseThrow(() -> new BusinessException("Không tìm thấy bản ghi chấm công"));
        userScheduleRepository.findLockedById(attendance.getSchedule().getId());
        entityManager.refresh(attendance);

        // Verify thuộc về user
        if (!attendance.getUser().getId().equals(userId)) {
            throw new BusinessException("Bản ghi chấm công không thuộc về bạn");
        }

        if (attendance.getCheckOutTime() != null) {
            throw new BusinessException("Bạn đã check-out rồi");
        }

        // Cập nhật check-out
        attendance.setCheckOutTime(LocalDateTime.now());
        attendance = attendanceRepository.save(attendance);

        // Cập nhật trạng thái schedule
        UserSchedule schedule = attendance.getSchedule();
        schedule.setStatus(ScheduleStatus.CHECKED_OUT);
        userScheduleRepository.save(schedule);

        log.info("Check-out thành công: user={}, attendance={}", userId, attendanceId);

        return toResponse(attendance);
    }

    // ========================= HISTORY =========================

    /**
     * Lấy lịch sử chấm công của user.
     */
    @Transactional(readOnly = true)
    public List<AttendanceResponse> getHistory(Long userId) {
        return attendanceRepository.findByUserIdOrderByCheckInTimeDesc(userId)
                .stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    // ========================= HAVERSINE =========================

    /**
     * Tính khoảng cách giữa 2 tọa độ GPS bằng công thức Haversine.
     * Trả về khoảng cách tính bằng MÉT.
     *
     * Công thức Haversine:
     *   a = sin²(Δlat/2) + cos(lat1) * cos(lat2) * sin²(Δlng/2)
     *   c = 2 * atan2(√a, √(1−a))
     *   d = R * c
     *
     * @param lat1 Vĩ độ điểm 1 (user)
     * @param lng1 Kinh độ điểm 1 (user)
     * @param lat2 Vĩ độ điểm 2 (store)
     * @param lng2 Kinh độ điểm 2 (store)
     * @return Khoảng cách (mét)
     */
    private double calculateHaversineDistance(double lat1, double lng1, double lat2, double lng2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);

        double radLat1 = Math.toRadians(lat1);
        double radLat2 = Math.toRadians(lat2);

        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                 + Math.cos(radLat1) * Math.cos(radLat2)
                 * Math.sin(dLng / 2) * Math.sin(dLng / 2);

        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return EARTH_RADIUS_METERS * c;
    }

    // ========================= MAPPER =========================

    /**
     * Map entity Attendance sang DTO AttendanceResponse.
     */
    private AttendanceResponse toResponse(Attendance attendance) {
        return AttendanceResponse.builder()
                .id(attendance.getId())
                .userId(attendance.getUser().getId())
                .userName(attendance.getUser().getName())
                .scheduleId(attendance.getSchedule().getId())
                .shiftName(attendance.getSchedule().getShift().getName())
                .checkInTime(attendance.getCheckInTime())
                .checkOutTime(attendance.getCheckOutTime())
                .checkInLat(attendance.getCheckInLat())
                .checkInLng(attendance.getCheckInLng())
                .status(attendance.getSchedule().getStatus().name())
                .build();
    }
}
