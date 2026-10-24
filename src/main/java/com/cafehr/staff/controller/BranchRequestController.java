package com.cafehr.staff.controller;

import com.cafehr.common.dto.ApiResponse;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.staff.dto.BranchRequestCreate;
import com.cafehr.staff.entity.BranchRequest;
import com.cafehr.staff.repository.BranchRequestRepository;
import com.cafehr.staff.service.StaffRequestService;
import com.cafehr.staff.view.StaffViews;
import com.cafehr.user.entity.User;
import com.cafehr.user.repository.UserRepository;

import org.springframework.security.access.prepost.PreAuthorize;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/requests")
@RequiredArgsConstructor
@PreAuthorize("hasRole('STAFF')")
public class BranchRequestController {

    private final UserRepository userRepository;
    private final BranchRequestRepository branchRequestRepository;
    private final StaffRequestService staffRequestService;

    @GetMapping("/mine")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getMyRequests(HttpServletRequest request) {
        User user = getCurrentUser(request);
        List<Map<String, Object>> items = branchRequestRepository.findByUserIdOrderByCreatedAtDesc(user.getId())
                .stream().map(this::toResponse).toList();
        return ResponseEntity.ok(ApiResponse.ok("Yêu cầu của tôi", items));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> createRequest(
            HttpServletRequest request,
            @Valid @RequestBody BranchRequestCreate body) {
        return ResponseEntity.ok(ApiResponse.ok("Đã gửi yêu cầu",
                staffRequestService.create(getCurrentUser(request).getId(), body)));
    }

    @PutMapping("/{id}/cancel")
    public ResponseEntity<ApiResponse<Map<String, Object>>> cancel(HttpServletRequest request, @PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.ok("Đã hủy yêu cầu",
                staffRequestService.cancel(getCurrentUser(request).getId(), id)));
    }

    private User getCurrentUser(HttpServletRequest request) {
        Object id = request.getAttribute("userId");
        if (!(id instanceof Long userId)) {
            throw new BusinessException("Không thể xác định tài khoản");
        }
        return userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException("Không tìm thấy tài khoản"));
    }

    private Map<String, Object> toResponse(BranchRequest item) {
        return StaffViews.request(item);
    }
}
