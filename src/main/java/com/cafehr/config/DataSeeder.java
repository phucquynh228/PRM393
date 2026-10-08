package com.cafehr.config;

import com.cafehr.entity.*;
import com.cafehr.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.LocalTime;

/**
 * Data Seeder — tự động tạo dữ liệu mẫu khi khởi động app.
 * Chỉ seed nếu bảng users chưa có dữ liệu (tránh tạo trùng).
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class DataSeeder implements CommandLineRunner {

    private final UserRepository userRepository;
    private final StoreRepository storeRepository;
    private final ShiftRepository shiftRepository;
    private final UserScheduleRepository userScheduleRepository;
    private final SystemConfigRepository systemConfigRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {
        if (userRepository.count() > 0) {
            log.info("[SEEDER] Dữ liệu đã tồn tại, bỏ qua seeding.");
            return;
        }

        log.info("[SEEDER] Bắt đầu tạo dữ liệu mẫu...");

        // ========================= STORES =========================
        Store store1 = storeRepository.save(Store.builder()
                .name("Cafe Thủ Đức")
                .latitude(10.8512)     // Tọa độ FPT University HCM
                .longitude(106.7718)
                .allowedRadius(200)    // 200 mét
                .build());

        Store store2 = storeRepository.save(Store.builder()
                .name("Cafe Quận 1")
                .latitude(10.7769)
                .longitude(106.7009)
                .allowedRadius(150)
                .build());

        Store store3 = storeRepository.save(Store.builder()
                .name("Cafe Bình Thạnh")
                .latitude(10.8013)
                .longitude(106.7100)
                .allowedRadius(180)
                .build());

        log.info("[SEEDER] Đã tạo 3 stores");

        // ========================= SHIFTS =========================
        Shift shiftSang = shiftRepository.save(Shift.builder()
                .name("Ca Sáng")
                .startTime(LocalTime.of(7, 0))
                .endTime(LocalTime.of(12, 0))
                .build());

        Shift shiftChieu = shiftRepository.save(Shift.builder()
                .name("Ca Chiều")
                .startTime(LocalTime.of(12, 0))
                .endTime(LocalTime.of(17, 0))
                .build());

        Shift shiftToi = shiftRepository.save(Shift.builder()
                .name("Ca Tối")
                .startTime(LocalTime.of(17, 0))
                .endTime(LocalTime.of(22, 0))
                .build());

        log.info("[SEEDER] Đã tạo 3 shifts");

        // ========================= USERS =========================
        // Mật khẩu mặc định: 123456
        String encodedPassword = passwordEncoder.encode("123456");

        User admin = userRepository.save(User.builder()
                .name("Nguyễn Văn Admin")
                .phone("0901000001")
                .password(encodedPassword)
                .role(Role.ADMIN)
                .store(store1)
                .build());

        User manager = userRepository.save(User.builder()
                .name("Trần Thị Manager")
                .phone("0901000002")
                .password(encodedPassword)
                .role(Role.MANAGER)
                .store(store1)
                .build());

        User staff1 = userRepository.save(User.builder()
                .name("Lê Văn Staff 1")
                .phone("0901000003")
                .password(encodedPassword)
                .role(Role.STAFF)
                .store(store1)
                .build());

        User staff2 = userRepository.save(User.builder()
                .name("Phạm Thị Staff 2")
                .phone("0901000004")
                .password(encodedPassword)
                .role(Role.STAFF)
                .store(store2)
                .build());

        User staff3 = userRepository.save(User.builder()
                .name("Hoàng Văn Staff 3")
                .phone("0901000005")
                .password(encodedPassword)
                .role(Role.STAFF)
                .store(store3)
                .build());

        log.info("[SEEDER] Đã tạo 5 users (1 admin, 1 manager, 3 staff)");

        // ========================= USER SCHEDULES (Hôm nay) =========================
        LocalDate today = LocalDate.now();

        userScheduleRepository.save(UserSchedule.builder()
                .user(staff1)
                .shift(shiftSang)
                .date(today)
                .status(ScheduleStatus.PENDING)
                .build());

        userScheduleRepository.save(UserSchedule.builder()
                .user(staff1)
                .shift(shiftChieu)
                .date(today)
                .status(ScheduleStatus.PENDING)
                .build());

        userScheduleRepository.save(UserSchedule.builder()
                .user(staff2)
                .shift(shiftSang)
                .date(today)
                .status(ScheduleStatus.PENDING)
                .build());

        userScheduleRepository.save(UserSchedule.builder()
                .user(staff3)
                .shift(shiftToi)
                .date(today)
                .status(ScheduleStatus.PENDING)
                .build());

        userScheduleRepository.save(UserSchedule.builder()
                .user(manager)
                .shift(shiftSang)
                .date(today)
                .status(ScheduleStatus.PENDING)
                .build());

        log.info("[SEEDER] Đã tạo 5 user schedules cho ngày {}", today);

        // ========================= SYSTEM CONFIG =========================
        systemConfigRepository.save(SystemConfig.builder()
                .configKey("reminder_minutes")
                .configValue("10")
                .build());

        log.info("[SEEDER] Đã tạo system config: reminder_minutes=10");

        log.info("=====================================================");
        log.info("[SEEDER] SEED HOÀN TẤT! Tài khoản test:");
        log.info("  ADMIN   : 0901000001 / 123456");
        log.info("  MANAGER : 0901000002 / 123456");
        log.info("  STAFF 1 : 0901000003 / 123456 (Cafe Thủ Đức)");
        log.info("  STAFF 2 : 0901000004 / 123456 (Cafe Quận 1)");
        log.info("  STAFF 3 : 0901000005 / 123456 (Cafe Bình Thạnh)");
        log.info("=====================================================");
    }
}
