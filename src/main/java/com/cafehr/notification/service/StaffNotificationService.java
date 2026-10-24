package com.cafehr.notification.service;

import com.cafehr.notification.entity.StaffNotification;
import com.cafehr.notification.repository.StaffNotificationRepository;
import com.cafehr.schedule.entity.UserSchedule;
import com.cafehr.user.entity.User;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.UUID;

@Service @RequiredArgsConstructor
public class StaffNotificationService {
    private final StaffNotificationRepository repository;

    @Transactional
    public void send(User user, String title, String message, String kind) {
        sendOnce(user, title, message, kind, UUID.randomUUID().toString());
    }

    @Transactional
    public void sendOnce(User user, String title, String message, String kind, String key) {
        if (!repository.existsByDedupeKey(key)) {
            repository.save(StaffNotification.builder().user(user).title(title).message(message)
                    .kind(kind).dedupeKey(key).build());
        }
    }

    public void scheduleChanged(UserSchedule schedule, String title) {
        if (schedule.isPublished()) {
            send(schedule.getUser(), title,
                    schedule.getShift().getName() + " · " + schedule.getDate() + " · "
                            + schedule.getShift().getStartTime() + " – " + schedule.getShift().getEndTime(), "SCHEDULE");
        }
    }
}
