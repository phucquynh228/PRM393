import org.springframework.security.crypto.bcrypt.BCrypt;

class DemoPassword {
    public static void main(String[] args) {
        String hash = BCrypt.hashpw("123456", BCrypt.gensalt(10));
        if (!BCrypt.checkpw("123456", hash)) throw new IllegalStateException("Password check failed");
        System.out.println(hash);
    }
}
