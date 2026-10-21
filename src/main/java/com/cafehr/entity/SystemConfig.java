package com.cafehr.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.Nationalized;

/**
 * Entity lưu cấu hình động của hệ thống (key-value).
 * Ví dụ: reminder_minutes = 10
 */
@Entity
@Table(name = "system_configs")
@Getter
@Setter
@Builder
public class SystemConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 100)
    private String configKey;

    @Nationalized
    @Column(nullable = false, length = 500)
    private String configValue;

    public SystemConfig() {
    }

    public SystemConfig(Long id, String configKey, String configValue) {
        this.id = id;
        this.configKey = configKey;
        this.configValue = configValue;
    }
}
