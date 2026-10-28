package com.cafehr.staff.repository;

import com.cafehr.staff.entity.BranchRequest;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;

import java.util.List;
import java.util.Optional;

public interface BranchRequestRepository extends JpaRepository<BranchRequest, Long> {

    boolean existsByStoreId(Long storeId);
    List<BranchRequest> findByStoreIdOrderByCreatedAtDesc(Long storeId);

    @Query("select r from BranchRequest r where r.status = com.cafehr.staff.entity.BranchRequestStatus.PENDING and (r.user.id = :userId or r.targetUserId = :userId)")
    List<BranchRequest> findPendingInvolvingUser(@Param("userId") Long userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from BranchRequest r where r.id = :id")
    Optional<BranchRequest> findLockedById(@Param("id") Long id);

    List<BranchRequest> findByUserStoreIdOrderByCreatedAtDesc(Long storeId);

    List<BranchRequest> findByUserIdOrderByCreatedAtDesc(Long userId);

    Optional<BranchRequest> findByIdAndUserStoreId(Long id, Long storeId);
}
