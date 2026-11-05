package com.cafehr.auth.repository;

import com.cafehr.auth.entity.PasswordSupportRequest;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface PasswordSupportRepository extends JpaRepository<PasswordSupportRequest, Long> {
    boolean existsByUserIdOrHandledById(Long userId, Long handledById);
    Optional<PasswordSupportRequest> findFirstByUserIdOrderByCreatedAtDesc(Long userId);
    List<PasswordSupportRequest> findTop100ByStatusOrderByCreatedAtDesc(PasswordSupportRequest.Status status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from PasswordSupportRequest r where r.id = :id")
    Optional<PasswordSupportRequest> findLockedById(@Param("id") Long id);
}
