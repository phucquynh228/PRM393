package com.cafehr.repository;

import com.cafehr.entity.UserSchedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.data.jpa.repository.Lock;
import jakarta.persistence.LockModeType;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface UserScheduleRepository extends JpaRepository<UserSchedule, Long> {

    List<UserSchedule> findByUserIdAndDateBetweenAndPublishedTrueOrderByDateAscShiftStartTimeAsc(
            Long userId, LocalDate from, LocalDate to);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from UserSchedule s where s.id = :id")
    Optional<UserSchedule> findLockedById(@Param("id") Long id);

    /**
     * Tìm tất cả schedule của một user vào ngày cụ thể.
     */
    List<UserSchedule> findByUserIdAndDate(Long userId, LocalDate date);

    List<UserSchedule> findByUserIdAndDateAndPublishedTrue(Long userId, LocalDate date);

    List<UserSchedule> findByUserStoreIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(
            Long storeId, LocalDate from, LocalDate to);

    List<UserSchedule> findByUserStoreIdAndDateBetweenAndPublishedTrueOrderByDateAscShiftStartTimeAsc(
            Long storeId, LocalDate from, LocalDate to);

    boolean existsByUserIdAndDateAndShiftId(Long userId, LocalDate date, Long shiftId);

    /**
     * Tìm schedule cụ thể của user vào ngày hôm nay (dùng cho check-in).
     */
    Optional<UserSchedule> findFirstByUserIdAndDateAndPublishedTrueOrderByIdAsc(Long userId, LocalDate date);

    /**
     * Tìm tất cả schedule ngày hôm nay có shift.startTime = thời gian chỉ định.
     * Dùng cho NotificationService (nhắc nhở trước ca).
     */
    @Query("SELECT us FROM UserSchedule us " +
           "JOIN FETCH us.shift s " +
           "JOIN FETCH us.user u " +
           "WHERE us.date = :date AND us.published = true")
    List<UserSchedule> findSchedulesWithShiftAndUserByDate(
            @Param("date") LocalDate date);
}
