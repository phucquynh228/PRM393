package com.cafehr.notification.repository;

import com.cafehr.notification.entity.StaffNotification;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface StaffNotificationRepository extends JpaRepository<StaffNotification, Long> {
    List<StaffNotification> findTop100ByUserIdOrderByCreatedAtDescIdDesc(Long userId);
    Optional<StaffNotification> findByIdAndUserId(Long id, Long userId);
    boolean existsByDedupeKey(String dedupeKey);
}
