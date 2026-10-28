package com.cafehr.staff.entity;

import com.cafehr.user.entity.User;
import com.cafehr.branch.entity.Store;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Nationalized;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "branch_requests")
@Getter
@Setter
@Builder
@AllArgsConstructor
public class BranchRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "store_id")
    private Store store;

    @Nationalized @Column(length = 150)
    private String storeName;

    @Column(length = 50)
    private String storeCode;

    @PrePersist
    public void captureStore() {
        if (store == null && user != null) store = user.getStore();
        if (store != null) {
            if (storeName == null) storeName = store.getName();
            if (storeCode == null) storeCode = store.getCode();
        }
    }

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private BranchRequestType type;

    @Column(nullable = false)
    private LocalDate startDate;

    @Column(nullable = false)
    private LocalDate endDate;

    @Nationalized
    @Column(nullable = false, length = 1000)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private BranchRequestStatus status = BranchRequestStatus.PENDING;

    @Nationalized
    @Column(length = 1000)
    private String managerNote;

    @Column(nullable = false)
    @Builder.Default
    private LocalDateTime createdAt = LocalDateTime.now();

    private Long sourceScheduleId;
    private Long targetScheduleId;
    private Long sourceShiftId;
    private Long targetShiftId;
    private Long targetUserId;
    private LocalDateTime requestedCheckIn;
    private LocalDateTime requestedCheckOut;

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
