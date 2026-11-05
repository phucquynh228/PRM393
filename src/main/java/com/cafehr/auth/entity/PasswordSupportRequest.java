package com.cafehr.auth.entity;

import com.cafehr.user.entity.User;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Nationalized;
import java.time.LocalDateTime;

@Entity
@Table(name = "password_support_requests", indexes = @Index(columnList = "user_id,created_at"))
@Getter @Setter @NoArgsConstructor
public class PasswordSupportRequest {
    public enum Status { PENDING, RESOLVED, REJECTED }

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
    @Nationalized @Column(nullable = false, length = 100)
    private String requestedName;
    @Nationalized @Column(length = 500)
    private String note;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20)
    private Status status = Status.PENDING;
    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
    private LocalDateTime handledAt;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "handled_by")
    private User handledBy;
    @Nationalized @Column(length = 500)
    private String adminNote;
}
