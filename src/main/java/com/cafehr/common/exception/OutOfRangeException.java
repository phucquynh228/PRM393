package com.cafehr.common.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/**
 * Exception khi user ở ngoài phạm vi chấm công (GPS radius).
 * Trả về HTTP 400 Bad Request.
 */
@ResponseStatus(HttpStatus.BAD_REQUEST)
public class OutOfRangeException extends RuntimeException {

    public OutOfRangeException(String message) {
        super(message);
    }
}
