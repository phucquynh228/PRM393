package com.cafehr.repository;

import com.cafehr.entity.BranchRequest;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface BranchRequestRepository extends JpaRepository<BranchRequest, Long> {

    List<BranchRequest> findByUserStoreIdOrderByCreatedAtDesc(Long storeId);

    List<BranchRequest> findByUserIdOrderByCreatedAtDesc(Long userId);

    Optional<BranchRequest> findByIdAndUserStoreId(Long id, Long storeId);
}
