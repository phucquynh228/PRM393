package com.cafehr.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Entity đại diện cho bản ghi chấm công.
 * Lưu thời gian check-in/out và tọa độ GPS lúc check-in.
 */
@Entity
@Table(name = "attendances")
@Getter
@Setter
@Builder
public class Attendance {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "schedule_id", nullable = false)
    private UserSchedule schedule;

    @Column(nullable = false)
    private LocalDateTime checkInTime;

    private LocalDateTime checkOutTime;

    @Column(nullable = false)
    private Double checkInLat;

    @Column(nullable = false)
    private Double checkInLng;

    public Attendance() {
    }

    public Attendance(Long id, User user, UserSchedule schedule, LocalDateTime checkInTime, LocalDateTime checkOutTime, Double checkInLat, Double checkInLng) {
        this.id = id;
        this.user = user;
        this.schedule = schedule;
        this.checkInTime = checkInTime;
        this.checkOutTime = checkOutTime;
        this.checkInLat = checkInLat;
        this.checkInLng = checkInLng;
    }
}
