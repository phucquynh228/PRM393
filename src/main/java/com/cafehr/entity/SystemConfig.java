package com.cafehr.entity;

import jakarta.persistence.*;
import lombok.*;

/**
 * Entity lưu cấu hình động của hệ thống (key-value).
 * Ví dụ: reminder_minutes = 10
 */
@Entity
@Table(name = "system_configs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SystemConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 100)
    private String configKey;

    @Column(nullable = false, length = 500)
    private String configValue;
}
