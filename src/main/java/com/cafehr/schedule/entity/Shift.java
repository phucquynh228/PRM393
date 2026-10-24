package com.cafehr.schedule.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Nationalized;

import java.time.LocalTime;

/**
 * Entity đại diện cho ca làm việc.
 */
@Entity
@Table(name = "shifts")
@Getter
@Setter
@Builder
@AllArgsConstructor
public class Shift {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Nationalized
    @Column(nullable = false, length = 100)
    private String name;

    @Column(nullable = false)
    private LocalTime startTime;

    @Column(nullable = false)
    private LocalTime endTime;

    @Column(nullable = false, columnDefinition = "int default 0")
    @Builder.Default
    private int breakMinutes = 0;

    @Column(nullable = false, columnDefinition = "bit default 1")
    @Builder.Default
    private boolean active = true;

    public Shift() {
        this.active = true;
    }

    public Shift(Long id, String name, LocalTime startTime, LocalTime endTime) {
        this.id = id;
        this.name = name;
        this.startTime = startTime;
        this.endTime = endTime;
        this.active = true;
    }
}
