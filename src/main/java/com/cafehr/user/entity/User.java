package com.cafehr.user.entity;

import com.cafehr.branch.entity.Store;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Nationalized;

/**
 * Entity đại diện cho nhân viên / người dùng trong hệ thống.
 * Mỗi user thuộc một Store và được gắn với một thiết bị duy nhất (deviceId).
 */
@Entity
@Table(name = "users")
@Getter
@Setter
@Builder
@AllArgsConstructor
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Nationalized
    @Column(nullable = false, length = 100)
    private String name;

    @Column(nullable = false, unique = true, length = 15)
    private String phone;

    @Column(nullable = false)
    private String password;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24, columnDefinition = "varchar(24) default 'ACTIVE'")
    @Builder.Default
    private EmploymentStatus employmentStatus = EmploymentStatus.ACTIVE;

    /**
     * ID thiết bị được bind với tài khoản.
     * Null nếu chưa bind lần đầu.
     */
    @Column(length = 255)
    private String deviceId;

    /**
     * Quan hệ Many-to-One với Store.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "store_id")
    private Store store;

    @Column(length = 150)
    private String email;

    @Column(length = 20)
    private String emergencyContact;

    @Nationalized
    @Column(length = 255)
    private String address;

    @ElementCollection
    @CollectionTable(name = "user_fixed_roster", joinColumns = @JoinColumn(name = "user_id"),
            uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "day_of_week", "slot"}))
    @Builder.Default
    private java.util.Set<com.cafehr.schedule.entity.FixedRosterEntry> fixedRoster = new java.util.HashSet<>();

    public User() {
        this.fixedRoster = new java.util.HashSet<>();
        this.employmentStatus = EmploymentStatus.ACTIVE;
    }

    public User(Long id, String name, String phone, String password, Role role, String deviceId, Store store) {
        this.id = id;
        this.fixedRoster = new java.util.HashSet<>();
        this.name = name;
        this.phone = phone;
        this.password = password;
        this.role = role;
        this.employmentStatus = EmploymentStatus.ACTIVE;
        this.deviceId = deviceId;
        this.store = store;
    }
}
