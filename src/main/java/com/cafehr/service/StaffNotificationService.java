package com.cafehr.service;

import com.cafehr.entity.*;
import com.cafehr.repository.StaffNotificationRepository;
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
