package com.cafehr.entity;

import jakarta.persistence.*;
import lombok.*;

/**
 * Entity đại diện cho cửa hàng trong chuỗi Cafe.
 * Chứa tọa độ GPS và bán kính cho phép chấm công.
 */
@Entity
@Table(name = "stores")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Store {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

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
}
