package com.cafehr.controller;

import com.cafehr.dto.ApiResponse;
import com.cafehr.dto.BranchRequestCreate;
import com.cafehr.entity.BranchRequest;
import com.cafehr.entity.BranchRequestStatus;
import com.cafehr.entity.Role;
import com.cafehr.entity.User;
import com.cafehr.exception.BusinessException;
import com.cafehr.repository.BranchRequestRepository;
import com.cafehr.repository.UserRepository;
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
public class BranchRequestController {

    private final UserRepository userRepository;
    private final BranchRequestRepository branchRequestRepository;

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
        User user = getCurrentUser(request);
        if (user.getRole() != Role.STAFF) {
            throw new BusinessException("Chỉ nhân viên mới có thể gửi yêu cầu");
        }
        if (user.getStore() == null) {
            throw new BusinessException("Tài khoản chưa được gán vào chi nhánh");
        }
        if (body.getEndDate().isBefore(body.getStartDate())) {
            throw new BusinessException("Ngày kết thúc không được trước ngày bắt đầu");
        }
        if (body.getStartDate().isBefore(LocalDate.now())) {
            throw new BusinessException("Không thể gửi yêu cầu cho ngày trong quá khứ");
        }
        String reason = body.getReason().trim();
        if (reason.length() > 1000) {
            throw new BusinessException("Lý do tối đa 1000 ký tự");
        }
        BranchRequest saved = branchRequestRepository.save(BranchRequest.builder()
                .user(user)
                .type(body.getType())
                .startDate(body.getStartDate())
                .endDate(body.getEndDate())
                .reason(reason)
                .status(BranchRequestStatus.PENDING)
                .createdAt(LocalDateTime.now())
                .build());
        return ResponseEntity.ok(ApiResponse.ok("Đã gửi yêu cầu", toResponse(saved)));
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
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("id", item.getId());
        response.put("type", item.getType().name());
        response.put("startDate", item.getStartDate());
        response.put("endDate", item.getEndDate());
        response.put("reason", item.getReason());
        response.put("status", item.getStatus().name());
        response.put("managerNote", item.getManagerNote());
        response.put("createdAt", item.getCreatedAt());
        return response;
    }
}
