package com.cafehr.auth.repository;

import com.cafehr.auth.entity.GoogleAccount;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface GoogleAccountRepository extends JpaRepository<GoogleAccount, Long> {
    Optional<GoogleAccount> findBySubject(String subject);
    Optional<GoogleAccount> findByUserId(Long userId);
}
