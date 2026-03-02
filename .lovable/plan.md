

# Plan: Permanent trusted devices + force re-login

## Changes

### 1. Remove 30-day expiry from `isDeviceTrusted` (`src/utils/deviceFingerprint.ts`)
- Remove the `TRUST_DAYS` / `TRUST_MS` expiry check — if device exists, it's trusted forever
- Remove `cleanupExpiredTrustedDevices` function (no longer needed)
- Keep `removeAllTrustedDevices` for manual management

### 2. Update `addTrustedDevice` (`src/utils/deviceFingerprint.ts`)
- Remove `created_at` reset on re-trust (no expiry cycle to reset)
- Keep upsert logic but only update `last_used_at` and `device_name`/`user_agent`

### 3. Update Login flow (`src/pages/Login.tsx`)
- Remove call to `cleanupExpiredTrustedDevices` on login (line 193)
- Change toast message from "30 dni" to "na stałe" (line 265)
- Force trust: after 2FA verification, always add device as trusted (remove the `if (trustDevice)` condition — device is always saved)

### 4. Update `TwoFactorVerification.tsx`
- Remove the "trust this device" checkbox — trusting is mandatory, not optional
- Always pass `trustDevice: true` to `onVerified`

### 5. Update `TrustedDevicesTab.tsx`
- Remove `TRUST_PERIOD_DAYS`, `getDaysRemaining`, `getExpiryBadge`, expired device cleanup button
- Show simpler UI: device list with "Added on" date, no expiry badges
- Keep "remove device" and "remove all" functionality

### 6. Force logout all users (SQL migration)
- Delete all records from `trusted_devices` table (forces everyone to re-verify)
- Truncate active sessions: call `auth.sign_out_all()` or delete from `auth.sessions` — since we can't modify auth schema, we'll delete all `trusted_devices` entries so every user must re-verify on next login

### 7. Update `SecuritySettingsManagement.tsx` description
- Update the 2FA description text to reflect permanent device trust instead of 30-day

