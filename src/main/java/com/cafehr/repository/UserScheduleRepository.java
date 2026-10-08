package com.cafehr.repository;

import com.cafehr.entity.UserSchedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface UserScheduleRepository extends JpaRepository<UserSchedule, Long> {

    /**
     * Tìm tất cả schedule của một user vào ngày cụ thể.
     */
    List<UserSchedule> findByUserIdAndDate(Long userId, LocalDate date);

    /**
     * Tìm schedule cụ thể của user vào ngày hôm nay (dùng cho check-in).
     */
    Optional<UserSchedule> findFirstByUserIdAndDateOrderByIdAsc(Long userId, LocalDate date);

    /**
     * Tìm tất cả schedule ngày hôm nay có shift.startTime = thời gian chỉ định.
     * Dùng cho NotificationService (nhắc nhở trước ca).
     */
    @Query("SELECT us FROM UserSchedule us " +
           "JOIN FETCH us.shift s " +
           "JOIN FETCH us.user u " +
           "WHERE us.date = :date")
    List<UserSchedule> findSchedulesWithShiftAndUserByDate(
            @Param("date") LocalDate date);
}
