package com.cafehr.common.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/**
 * Exception khi thiết bị đăng nhập không khớp với thiết bị đã bind.
 * Trả về HTTP 403 Forbidden.
 */
@ResponseStatus(HttpStatus.FORBIDDEN)
public class DeviceNotMatchException extends RuntimeException {

    public DeviceNotMatchException(String message) {
        super(message);
    }
}
