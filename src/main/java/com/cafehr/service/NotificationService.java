package com.cafehr.service;

import com.cafehr.entity.UserSchedule;
import com.cafehr.repository.SystemConfigRepository;
import com.cafehr.repository.UserScheduleRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.List;

/**
 * Service xử lý gửi thông báo nhắc nhở trước ca làm việc.
 *
 * Logic:
 * - Chạy cron job mỗi phút.
 * - Đọc cấu hình `reminder_minutes` từ bảng SystemConfig (mặc định = 10 phút).
 * - Tìm tất cả UserSchedule ngày hôm nay có shift.startTime = (thời gian hiện tại + reminder_minutes).
 * - Gửi FCM notification cho từng user (giả lập).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationService {

    private final UserScheduleRepository userScheduleRepository;
    private final SystemConfigRepository systemConfigRepository;

    /** Giá trị mặc định nếu không tìm thấy config trong DB */
    private static final int DEFAULT_REMINDER_MINUTES = 10;

    /**
     * Cron job chạy mỗi phút (giây 0 của mỗi phút).
     * Kiểm tra và gửi thông báo nhắc nhở trước ca.
     */
    @Scheduled(cron = "0 * * * * *")
    public void sendShiftReminders() {
        log.debug("=== [CRON] Bắt đầu kiểm tra nhắc nhở ca làm việc ===");

        try {
            // 1. Lấy cấu hình reminder_minutes từ SystemConfig
            int reminderMinutes = getReminderMinutes();

            // 2. Tính thời gian shift cần nhắc nhở
            //    Nếu bây giờ là 07:50 và reminder = 10 phút -> tìm shift startTime = 08:00
            LocalTime targetStartTime = LocalTime.now()
                    .plusMinutes(reminderMinutes)
                    .truncatedTo(ChronoUnit.MINUTES);

            LocalDate today = LocalDate.now();

            log.debug("[CRON] reminder_minutes={}, targetStartTime={}, date={}",
                    reminderMinutes, targetStartTime, today);

            // 3. Tìm tất cả schedule hôm nay có shift bắt đầu đúng targetStartTime
            List<UserSchedule> schedules = userScheduleRepository
                    .findSchedulesWithShiftAndUserByDate(today)
                    .stream()
                    .filter(s -> s.getShift().getStartTime().equals(targetStartTime))
                    .toList();

            if (schedules.isEmpty()) {
                log.debug("[CRON] Không có ca nào cần nhắc nhở lúc {}", targetStartTime);
                return;
            }

            log.info("[CRON] Tìm thấy {} ca cần nhắc nhở (startTime={})",
                    schedules.size(), targetStartTime);

            // 4. Gửi thông báo cho từng user
            for (UserSchedule schedule : schedules) {
                Long userId = schedule.getUser().getId();
                String userName = schedule.getUser().getName();
                String shiftName = schedule.getShift().getName();
                LocalTime startTime = schedule.getShift().getStartTime();

                String message = String.format(
                        "Nhắc nhở: Bạn có ca \"%s\" bắt đầu lúc %s (còn %d phút). Hãy chuẩn bị chấm công!",
                        shiftName, startTime, reminderMinutes
                );

                sendFCMNotification(userId, userName, message);
            }

            log.info("[CRON] Đã gửi {} thông báo nhắc nhở", schedules.size());

        } catch (Exception e) {
            log.error("[CRON] Lỗi khi xử lý nhắc nhở ca làm việc: {}", e.getMessage(), e);
        }
    }

    /**
     * Lấy giá trị `reminder_minutes` từ bảng SystemConfig.
     * Trả về giá trị mặc định nếu không tìm thấy hoặc giá trị không hợp lệ.
     */
    private int getReminderMinutes() {
        return systemConfigRepository.findByConfigKey("reminder_minutes")
                .map(config -> {
                    try {
                        int value = Integer.parseInt(config.getConfigValue());
                        if (value < 1 || value > 120) {
                            log.warn("[CONFIG] reminder_minutes={} ngoài phạm vi hợp lệ (1-120), dùng mặc định={}",
                                    value, DEFAULT_REMINDER_MINUTES);
                            return DEFAULT_REMINDER_MINUTES;
                        }
                        return value;
                    } catch (NumberFormatException e) {
                        log.warn("[CONFIG] reminder_minutes không phải số: '{}', dùng mặc định={}",
                                config.getConfigValue(), DEFAULT_REMINDER_MINUTES);
                        return DEFAULT_REMINDER_MINUTES;
                    }
                })
                .orElseGet(() -> {
                    log.info("[CONFIG] Không tìm thấy config 'reminder_minutes', dùng mặc định={}",
                            DEFAULT_REMINDER_MINUTES);
                    return DEFAULT_REMINDER_MINUTES;
                });
    }

    /**
     * Giả lập gửi FCM Push Notification.
     * Trong thực tế, sẽ tích hợp Firebase Admin SDK tại đây.
     *
     * @param userId   ID của user nhận thông báo
     * @param userName Tên user (để log)
     * @param message  Nội dung thông báo
     */
    private void sendFCMNotification(Long userId, String userName, String message) {
        // =====================================================
        // TODO: Tích hợp Firebase Admin SDK để gửi push thực tế
        // FirebaseMessaging.getInstance().send(...)
        // =====================================================

        log.info("[FCM] >> Gửi thông báo đến user '{}' (id={}): {}", userName, userId, message);
    }
}
