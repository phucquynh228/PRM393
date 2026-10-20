package com.cafehr.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "branch_requests")
@Getter
@Setter
@Builder
public class BranchRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private BranchRequestType type;

    @Column(nullable = false)
    private LocalDate startDate;

    @Column(nullable = false)
    private LocalDate endDate;

    @Column(nullable = false, length = 1000)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private BranchRequestStatus status = BranchRequestStatus.PENDING;

    @Column(length = 1000)
    private String managerNote;

    @Column(nullable = false)
    @Builder.Default
    private LocalDateTime createdAt = LocalDateTime.now();

    public BranchRequest() {
    }

    public BranchRequest(Long id, User user, BranchRequestType type, LocalDate startDate,
                         LocalDate endDate, String reason, BranchRequestStatus status,
                         String managerNote, LocalDateTime createdAt) {
        this.id = id;
        this.user = user;
        this.type = type;
        this.startDate = startDate;
        this.endDate = endDate;
        this.reason = reason;
        this.status = status != null ? status : BranchRequestStatus.PENDING;
        this.managerNote = managerNote;
        this.createdAt = createdAt != null ? createdAt : LocalDateTime.now();
    }
}
