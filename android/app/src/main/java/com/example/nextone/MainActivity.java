package com.example.nextone;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.WindowManager;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "nextone/screen_security";
    private static final String PREFS_NAME = "FlutterSharedPreferences";
    private static final String ROLE_KEY = "flutter.user_role";
    private static final String ADMIN_ROLE = "admin";
    private static final String SUPER_ADMIN_ROLE = "super_admin";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        applyScreenSecurity(readStoredRole());
    }

    @Override
    protected void onResume() {
        super.onResume();
        applyScreenSecurity(readStoredRole());
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler(this::handleMethodCall);
    }

    private void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        if ("updateScreenSecurity".equals(call.method)) {
            final String role = readRoleArgument(call.arguments);
            applyScreenSecurity(role);
            result.success(null);
            return;
        }

        result.notImplemented();
    }

    private void applyScreenSecurity(String role) {
        if (isPrivilegedRole(role)) {
            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
        } else {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        }
    }

    private boolean isPrivilegedRole(String role) {
        if (role == null) {
            return false;
        }

        final String normalizedRole = role.trim().toLowerCase().replace(" ", "_");
        return ADMIN_ROLE.equals(normalizedRole) || SUPER_ADMIN_ROLE.equals(normalizedRole);
    }

    private String readStoredRole() {
        final SharedPreferences preferences =
                getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        return preferences.getString(ROLE_KEY, "");
    }

    private String readRoleArgument(Object arguments) {
        if (!(arguments instanceof java.util.Map)) {
            return "";
        }

        final Object role = ((java.util.Map<?, ?>) arguments).get("role");
        return role == null ? "" : role.toString();
    }
}
