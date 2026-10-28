package com.cafehr.attendance.repository;

import com.cafehr.attendance.entity.Attendance;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.time.LocalDateTime;

@Repository
public interface AttendanceRepository extends JpaRepository<Attendance, Long> {

    boolean existsByUserIdAndCheckOutTimeIsNull(Long userId);
    List<Attendance> findByScheduleStoreIdAndCheckOutTimeIsNull(Long storeId);
    List<Attendance> findByScheduleStoreIdAndCheckInTimeBetweenOrderByCheckInTimeDesc(Long storeId, LocalDateTime from, LocalDateTime to);

    /**
     * Tìm bản ghi chấm công theo scheduleId (kiểm tra đã check-in chưa).
     */
    Optional<Attendance> findByScheduleId(Long scheduleId);

    /**
     * Lấy lịch sử chấm công của user.
     */
    List<Attendance> findByUserIdOrderByCheckInTimeDesc(Long userId);

    List<Attendance> findByUserStoreIdAndCheckInTimeBetweenOrderByCheckInTimeDesc(
            Long storeId, LocalDateTime from, LocalDateTime to);
}
