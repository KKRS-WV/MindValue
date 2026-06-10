package com.mindvault.auth;

import com.mindvault.user.User;
import com.mindvault.user.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtService jwtService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new IllegalArgumentException("Email is already registered.");
        }

        User user = new User();
        user.setUsername(request.username());
        user.setEmail(request.email());
        user.setPassword(passwordEncoder.encode(request.password()));
        user = userRepository.save(user);

        return new AuthResponse(jwtService.createToken(user.getId().toString()), "Registered successfully.");
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.email())
            .orElseThrow(() -> new IllegalArgumentException("Invalid email or password."));

        if (!passwordEncoder.matches(request.password(), user.getPassword())) {
            throw new IllegalArgumentException("Invalid email or password.");
        }

        return new AuthResponse(jwtService.createToken(user.getId().toString()), "Logged in successfully.");
    }

    @Transactional(readOnly = true)
    public UserProfileResponse me(CurrentUser currentUser) {
        User user = userRepository.findById(currentUser.id())
            .orElseThrow(() -> new IllegalArgumentException("User not found."));
        return new UserProfileResponse(user.getId(), user.getUsername(), user.getEmail(), user.getAvatar());
    }

    @Transactional
    public UserProfileResponse updateMe(CurrentUser currentUser, UpdateProfileRequest request) {
        User user = userRepository.findById(currentUser.id())
            .orElseThrow(() -> new IllegalArgumentException("User not found."));

        userRepository.findByEmail(request.email())
            .filter(existing -> !existing.getId().equals(user.getId()))
            .ifPresent(existing -> {
                throw new IllegalArgumentException("Email is already registered.");
            });

        user.setUsername(request.username());
        user.setEmail(request.email());
        user.setAvatar(blankToNull(request.avatar()));

        return new UserProfileResponse(user.getId(), user.getUsername(), user.getEmail(), user.getAvatar());
    }

    private String blankToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value;
    }
}
