package com.cafehr.repository;

import com.cafehr.entity.SystemConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SystemConfigRepository extends JpaRepository<SystemConfig, Long> {

    /**
     * Tìm config theo key (ví dụ: "reminder_minutes").
     */
    Optional<SystemConfig> findByConfigKey(String configKey);
}
