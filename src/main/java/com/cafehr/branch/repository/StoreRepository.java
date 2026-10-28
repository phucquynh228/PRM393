package com.cafehr.branch.repository;

import com.cafehr.branch.entity.Store;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface StoreRepository extends JpaRepository<Store, Long> {

    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @org.springframework.data.jpa.repository.Query("select s from Store s where s.id = :id")
    Optional<Store> findLockedById(@org.springframework.data.repository.query.Param("id") Long id);

    java.util.List<Store> findByManagerId(Long managerId);

    boolean existsByCode(String code);

    boolean existsByCodeAndIdNot(String code, Long id);

    Optional<Store> findByCode(String code);
}
