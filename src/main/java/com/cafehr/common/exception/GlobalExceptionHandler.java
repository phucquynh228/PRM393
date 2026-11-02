package com.cafehr.common.exception;

import com.cafehr.auth.exception.GoogleAuthenticationException;
import com.cafehr.auth.exception.GoogleUnavailableException;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * Global exception handler — xử lý tập trung tất cả exception trong hệ thống.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(org.springframework.security.authentication.DisabledException.class)
    public ResponseEntity<Map<String, Object>> handleDisabled(org.springframework.security.authentication.DisabledException ex) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(buildErrorBody(HttpStatus.FORBIDDEN, "Tài khoản đã ngừng hoạt động"));
    }

    @ExceptionHandler(GoogleAuthenticationException.class)
    public ResponseEntity<Map<String, Object>> handleGoogleAuthentication(GoogleAuthenticationException ex) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(buildErrorBody(HttpStatus.UNAUTHORIZED, ex.getMessage()));
    }

    @ExceptionHandler(GoogleUnavailableException.class)
    public ResponseEntity<Map<String, Object>> handleGoogleUnavailable(GoogleUnavailableException ex) {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(buildErrorBody(HttpStatus.SERVICE_UNAVAILABLE, ex.getMessage()));
    }

    /**
     * Cấu trúc response lỗi chuẩn.
     */
    private Map<String, Object> buildErrorBody(HttpStatus status, String message) {
        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", LocalDateTime.now());
        body.put("status", status.value());
        body.put("error", status.getReasonPhrase());
        body.put("message", message);
        return body;
    }

    @ExceptionHandler(DeviceNotMatchException.class)
    public ResponseEntity<Map<String, Object>> handleDeviceNotMatch(DeviceNotMatchException ex) {
        return ResponseEntity
                .status(HttpStatus.FORBIDDEN)
                .body(buildErrorBody(HttpStatus.FORBIDDEN, ex.getMessage()));
    }

    @ExceptionHandler(OutOfRangeException.class)
    public ResponseEntity<Map<String, Object>> handleOutOfRange(OutOfRangeException ex) {
        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(buildErrorBody(HttpStatus.BAD_REQUEST, ex.getMessage()));
    }

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<Map<String, Object>> handleBusiness(BusinessException ex) {
        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(buildErrorBody(HttpStatus.BAD_REQUEST, ex.getMessage()));
    }

    @ExceptionHandler(BadCredentialsException.class)
    public ResponseEntity<Map<String, Object>> handleBadCredentials(BadCredentialsException ex) {
        return ResponseEntity
                .status(HttpStatus.UNAUTHORIZED)
                .body(buildErrorBody(HttpStatus.UNAUTHORIZED, "Số điện thoại hoặc mật khẩu không đúng"));
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<Map<String, Object>> handleAccessDenied(AccessDeniedException ex) {
        return ResponseEntity
                .status(HttpStatus.FORBIDDEN)
                .body(buildErrorBody(HttpStatus.FORBIDDEN, "Bạn không có quyền truy cập chức năng này"));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidation(MethodArgumentNotValidException ex) {
        Map<String, String> fieldErrors = new HashMap<>();
        for (FieldError error : ex.getBindingResult().getFieldErrors()) {
            fieldErrors.put(error.getField(), error.getDefaultMessage());
        }

        Map<String, Object> body = buildErrorBody(HttpStatus.BAD_REQUEST, "Dữ liệu không hợp lệ");
        body.put("fieldErrors", fieldErrors);

        return ResponseEntity.badRequest().body(body);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGeneric(Exception ex) {
        return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(buildErrorBody(HttpStatus.INTERNAL_SERVER_ERROR, "Lỗi hệ thống: " + ex.getMessage()));
    }
}
