package com.cafehr.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StoreRequest {

    @NotBlank(message = "Tên chi nhánh không được để trống")
    private String name;

    @NotNull(message = "Vĩ độ (latitude) không được để trống")
    private Double latitude;

    @NotNull(message = "Kinh độ (longitude) không được để trống")
    private Double longitude;

    @NotNull(message = "Bán kính cho phép không được để trống")
    private Integer allowedRadius;
}
