package com.cafehr.branch.entity;

import com.cafehr.user.entity.User;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Nationalized;

/**
 * Entity đại diện cho cửa hàng trong chuỗi Cafe.
 * Chứa mã chi nhánh, tên, định biên nhân sự, tọa độ GPS và trạng thái hoạt động.
 */
@Entity
@Table(name = "stores")
@Getter
@Setter
@Builder
@AllArgsConstructor
public class Store {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(length = 50)
    private String code; // Mã chuẩn hóa (Ví dụ: HN-CG01)

    @Nationalized
    @Column(nullable = false, length = 150)
    private String name;

    @Column(nullable = false)
    private Double latitude;

    @Column(nullable = false)
    private Double longitude;

    /**
     * Bán kính cho phép chấm công, tính bằng mét.
     */
    @Column(nullable = false)
    private Integer allowedRadius;

    /**
     * Định biên nhân sự tối đa (Max Staff)
     */
    @Column
    @Builder.Default
    private Integer maxStaff = 15;

    /**
     * Trạng thái hoạt động chi nhánh: ACTIVE, MAINTENANCE, CLOSED
     */
    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    @Builder.Default
    private StoreStatus status = StoreStatus.ACTIVE;

    private java.time.LocalDateTime closedAt;

    @org.hibernate.annotations.Nationalized
    @Column(length = 500)
    private String closureReason;

    /**
     * Cửa hàng trưởng (Manager) duy nhất của chi nhánh.
     */
    @OneToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "manager_id")
    private User manager;

    @ElementCollection
    @CollectionTable(name = "branch_shift_plans", joinColumns = @JoinColumn(name = "store_id"))
    @MapKeyEnumerated(EnumType.STRING)
    @MapKeyColumn(name = "slot", length = 20)
    @Builder.Default
    private java.util.Map<com.cafehr.schedule.entity.ShiftSlot, com.cafehr.schedule.entity.BranchShiftPlan> shiftPlans = new java.util.EnumMap<>(com.cafehr.schedule.entity.ShiftSlot.class);

    public Store() {
        this.shiftPlans = new java.util.EnumMap<>(com.cafehr.schedule.entity.ShiftSlot.class);
    }

    public Store(Long id, String code, String name, Double latitude, Double longitude, Integer allowedRadius, Integer maxStaff, StoreStatus status, User manager) {
        this.id = id;
        this.shiftPlans = new java.util.EnumMap<>(com.cafehr.schedule.entity.ShiftSlot.class);
        this.code = code;
        this.name = name;
        this.latitude = latitude;
        this.longitude = longitude;
        this.allowedRadius = allowedRadius;
        this.maxStaff = maxStaff != null ? maxStaff : 15;
        this.status = status != null ? status : StoreStatus.ACTIVE;
        this.manager = manager;
    }
}
