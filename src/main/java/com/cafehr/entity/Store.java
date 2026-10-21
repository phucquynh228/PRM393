package com.cafehr.entity;

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

    /**
     * Cửa hàng trưởng (Manager) duy nhất của chi nhánh.
     */
    @OneToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "manager_id")
    private User manager;

    public Store() {
    }

    public Store(Long id, String code, String name, Double latitude, Double longitude, Integer allowedRadius, Integer maxStaff, StoreStatus status, User manager) {
        this.id = id;
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
