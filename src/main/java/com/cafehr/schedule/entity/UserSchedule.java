package com.cafehr.schedule.entity;

import com.cafehr.user.entity.User;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

/**
 * Entity đại diện cho lịch làm việc được phân công cho nhân viên.
 * Mỗi record = 1 user được phân 1 ca (shift) vào 1 ngày cụ thể.
 */
@Entity
@Table(name = "user_schedules")
@Getter
@Setter
@Builder
public class UserSchedule {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "shift_id", nullable = false)
    private Shift shift;

    @Column(nullable = false)
    private LocalDate date;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ScheduleStatus status;

    @Column(nullable = false, columnDefinition = "bit default 1")
    @Builder.Default
    private boolean published = true;

    public UserSchedule() {
    }

    public UserSchedule(Long id, User user, Shift shift, LocalDate date, ScheduleStatus status) {
        this(id, user, shift, date, status, true);
    }

    public UserSchedule(
            Long id,
            User user,
            Shift shift,
            LocalDate date,
            ScheduleStatus status,
            boolean published) {
        this.id = id;
        this.user = user;
        this.shift = shift;
        this.date = date;
        this.status = status;
        this.published = published;
    }
}
