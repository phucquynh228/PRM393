package com.cafehr.schedule.repository;

import com.cafehr.schedule.entity.UserSchedule;

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

    @Query("""
            select new com.cafehr.attendance.dto.AttendanceReportRow(
                s.date, s.id, u.id, u.name,
                coalesce(s.storeCode, branch.code, currentStore.code),
                coalesce(s.storeName, branch.name, currentStore.name),
                shift.name, shift.startTime, shift.endTime, s.status,
                a.checkInTime, a.checkOutTime, a.manuallyAdjusted)
            from UserSchedule s
            join s.user u
            join s.shift shift
            left join s.store branch
            left join u.store currentStore
            left join Attendance a on a.schedule = s
            where s.published = true
                and s.status <> com.cafehr.schedule.entity.ScheduleStatus.CANCELLED
                and s.date between :from and :to
                and (:userId is null or u.id = :userId)
                and (:storeId is null or coalesce(branch.id, currentStore.id) = :storeId)
            order by s.date, u.id, shift.startTime, s.id, a.id
            """)
    List<com.cafehr.attendance.dto.AttendanceReportRow> findAttendanceReport(
            @Param("from") LocalDate from, @Param("to") LocalDate to,
            @Param("userId") Long userId, @Param("storeId") Long storeId);

    boolean existsByStoreId(Long storeId);
    List<UserSchedule> findByStoreIdOrderByDateAscShiftStartTimeAsc(Long storeId);
    List<UserSchedule> findByUserIdOrderByDateAscShiftStartTimeAsc(Long userId);

    List<UserSchedule> findByStoreIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(Long storeId, LocalDate from, LocalDate to);
    List<UserSchedule> findByStoreIdAndDateBetweenAndPublishedTrueOrderByDateAscShiftStartTimeAsc(Long storeId, LocalDate from, LocalDate to);

    boolean existsByShiftId(Long shiftId);

    List<UserSchedule> findByDateBetweenOrderByDateAscShiftStartTimeAsc(LocalDate from, LocalDate to);

    List<UserSchedule> findByUserIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(
            Long userId, LocalDate from, LocalDate to);

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
