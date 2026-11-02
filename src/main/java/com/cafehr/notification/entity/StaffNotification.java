package com.cafehr.notification.entity;

import com.cafehr.user.entity.User;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Nationalized;
import java.time.LocalDateTime;

@Entity
@Table(name = "staff_notifications", indexes = @Index(name = "idx_notification_user", columnList = "user_id,created_at"))
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class StaffNotification {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "user_id", nullable = false)
    private User user;
    @Nationalized @Column(nullable = false, length = 150)
    private String title;
    @Nationalized @Column(nullable = false, length = 2000)
    private String message;
    @Column(nullable = false, length = 30)
    private String kind;
    @Column(nullable = false, unique = true, length = 150)
    private String dedupeKey;
    @Builder.Default @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
    private LocalDateTime readAt;
}
