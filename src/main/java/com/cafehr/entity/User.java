package com.cafehr.entity;

import jakarta.persistence.*;
import lombok.*;

/**
 * Entity đại diện cho nhân viên / người dùng trong hệ thống.
 * Mỗi user thuộc một Store và được gắn với một thiết bị duy nhất (deviceId).
 */
@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(nullable = false, unique = true, length = 15)
    private String phone;

    @Column(nullable = false)
    private String password;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;

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
}
