package com.cafehr.schedule.entity;

import java.time.LocalTime;

public enum ShiftSlot {
    MORNING("Ca Sáng"), AFTERNOON("Ca Chiều"), EVENING("Ca Tối");
    private final String label;
    ShiftSlot(String label) { this.label = label; }
    public String label() { return label; }
    public static ShiftSlot fromStart(LocalTime time) {
        return time.isBefore(LocalTime.NOON) ? MORNING : time.isBefore(LocalTime.of(17, 0)) ? AFTERNOON : EVENING;
    }
}
