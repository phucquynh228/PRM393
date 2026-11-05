package com.cafehr.security;

import com.cafehr.user.entity.EmploymentStatus;
import com.cafehr.user.entity.User;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import java.util.List;

public class HrmUserDetails extends org.springframework.security.core.userdetails.User {
    private final long credentialsVersion;

    public HrmUserDetails(User user) {
        super(user.getPhone(), user.getPassword(), user.getEmploymentStatus() != EmploymentStatus.INACTIVE,
                true, true, true, List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole().name())));
        credentialsVersion = user.getCredentialsVersion();
    }

    public long getCredentialsVersion() { return credentialsVersion; }
}
