package com.cafehr.auth.entity;

import com.cafehr.user.entity.User;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity @Table(name = "google_accounts")
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class GoogleAccount {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, unique = true, length = 255)
    private String subject;
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;
    @Column(nullable = false, length = 320)
    private String email;
    @Builder.Default @Column(nullable = false)
    private LocalDateTime linkedAt = LocalDateTime.now();
}
