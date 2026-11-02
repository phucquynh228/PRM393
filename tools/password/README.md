# Công cụ mật khẩu demo

`DemoPassword.java` là công cụ Java chạy độc lập, tạo BCrypt cho mật khẩu mẫu `123456` và tự kiểm tra hash vừa tạo.
File không thuộc mã backend và không chạy khi Spring Boot khởi động.

Chạy từ thư mục gốc với JDK 17:

```powershell
.\mvnw.cmd dependency:build-classpath '-Dmdep.outputFile=target/tools-classpath.txt'
$demoClasspath = (Get-Content -Raw target/tools-classpath.txt).Trim()
java -cp $demoClasspath tools/password/DemoPassword.java
```

Mã nguồn đặt tại `tools/password` để không bị mất khi chạy Maven clean. Classpath và các kết quả build đặt tại `target`.
