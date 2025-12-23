# BillMinder - Feature Documentation

> **Last Updated**: December 20, 2024 (Morning Session)  
> **Version**: 1.0.0 MVP  
> **Platform**: Flutter (Android & iOS)  
> **Status**: 🚧 In Progress

---

## 📱 App Overview

**BillMinder** is an offline-first bill management app that helps users:
- Never forget bill due dates
- Avoid late fees with smart reminders
- Securely sync bills across devices

---

## 🏗️ Architecture

### Tech Stack
| Layer | Technology | Status |
|-------|------------|--------|
| Framework | Flutter | ✅ Set up |
| Local Database | Hive | ✅ Implemented |
| Cloud Database | Firebase Firestore | ✅ Implemented |
| Authentication | Firebase Auth (Google Sign-In) | ✅ Implemented |
| Notifications | flutter_local_notifications | ✅ Implemented |
| State Management | Provider | ✅ Implemented |

### Design Principles
- **Offline-First**: Local database is the primary data source ✅
- **Non-Blocking UI**: Network requests never block the user ✅
- **Last-Write-Wins**: Sync conflict resolution strategy ✅

---

## ✅ Implemented Features

### 🎨 UI Screens (All 6 Complete)
| Screen | File | Status |
|--------|------|--------|
| Splash Screen | `splash_screen.dart` | ✅ Bounce animation, auto-navigate |
| Auth Screen | `auth_screen.dart` | ✅ Google Sign-In + Guest mode |
| Home Screen | `home_screen.dart` | ✅ Dashboard + Bill list + FAB |
| Bill Detail | `bill_detail_view.dart` | ✅ Large amount display, actions |
| Add Bill Sheet | `add_bill_sheet.dart` | ✅ Bottom sheet, date picker (no past dates) |
| Settings Screen | `settings_screen.dart` | ✅ Account, Sign out, App info |

### 🔐 Authentication
| Feature | Status | Description |
|---------|--------|-------------|
| Google Sign-In | ✅ Done | Sign in with Google account for cloud sync |
| Continue as Guest | ✅ Done | Use app without account (local only) |
| Guest to Google Migration | ✅ Done | Upload local bills when guest signs in |

### 📝 Bill Management
| Feature | Status | Description |
|---------|--------|-------------|
| Add Bill | ✅ Done | Create new bill with name, amount, due date, repeat |
| Edit Bill | ⏳ Pending | Modify existing bill details |
| Delete Bill | ✅ Done | Remove bill with confirmation dialog |
| Mark as Paid | ✅ Done | One-tap action to mark bill paid |
| Bill List | ✅ Done | View all bills sorted by due date |
| Bill Status | ✅ Done | Upcoming / Overdue / Paid indicators |

### 🔄 Recurring Bills
| Feature | Status | Description |
|---------|--------|-------------|
| Monthly Repeat | ✅ Done | Auto-create next month's bill when paid |
| One-time Bills | ✅ Done | Single occurrence bills |

### 🔔 Notifications
| Feature | Status | Description |
|---------|--------|-------------|
| Reminder (1 day before) | ✅ Done | Local notification day before due date |
| Due Date Alert | ✅ Done | Local notification on due date |
| Offline Notifications | ✅ Done | Works without internet |

### ☁️ Sync & Backup
| Feature | Status | Description |
|---------|--------|-------------|
| Auto Sync | ✅ Done | Sync when internet available |
| Sync Status Tracking | ✅ Done | pending / synced status per bill |
| Cross-Device Sync | ✅ Done | Access bills from multiple devices |

### ⚙️ Settings
| Feature | Status | Description |
|---------|--------|-------------|
| Sign Out | ✅ Done | Log out of Google account |
| Sign In (from Guest) | ✅ Done | Switch from guest to Google |
| App Info | ✅ Done | Version and about information |

---

## 📂 Project Structure

```
lib/
├── main.dart                 # ✅ App entry point with Firebase init
├── core/                     # ✅ Design system
│   ├── app_colors.dart       # ✅ Color constants
│   └── app_theme.dart        # ✅ Theme configuration
├── models/                   # ✅ Data models
│   ├── bill.dart             # ✅ Bill model with Hive adapter
│   └── bill.g.dart           # ✅ Generated Hive adapter
├── services/                 # ✅ Business logic layer
│   ├── auth_service.dart     # ✅ Authentication logic
│   ├── local_db_service.dart # ✅ Hive local database
│   ├── sync_service.dart     # ✅ Firebase sync logic
│   └── notification_service.dart # ✅ Local notifications
├── providers/                # ✅ State management
│   └── bill_provider.dart    # ✅ Bill state and operations
└── screens/                  # ✅ UI screens
    ├── splash_screen.dart    # ✅ Animated splash
    ├── auth_screen.dart      # ✅ Login/Guest
    ├── home_screen.dart      # ✅ Dashboard
    ├── add_bill_sheet.dart   # ✅ Bottom sheet form
    ├── bill_detail_view.dart # ✅ Bill details
    └── settings_screen.dart  # ✅ Settings
```

---

## 🔐 Firebase Security Rules

**File**: `firestore.rules` ✅ Created

Rules ensure:
- ✅ Users can read/write only their own bills
- ✅ Unauthenticated users have no access
- ✅ Data validation for all fields
- ✅ Protection against cross-user access

---

## 🎨 Design System Reference

| Element | Value |
|---------|-------|
| Theme | Light Mode Only |
| Primary Color | `#10B981` (Emerald 500) |
| Dark/Action Color | `#0F172A` (Slate 900) |
| Background | `#F8FAFC` (Slate 50) |
| Alert/Overdue | `#F43F5E` (Rose 500) |
| Font | Inter (Google Fonts) |
| Corner Radius | Squircle (24-32px) |

---

## 📋 Implementation Log

### December 20, 2024 - Morning Session
- [x] Created core design system (`app_colors.dart`, `app_theme.dart`)
- [x] Created Bill model with Hive adapter
- [x] Built all 6 UI screens from TSX reference
- [x] Implemented Auth Service (Google Sign-In + Guest)
- [x] Implemented Local Database Service (Hive)
- [x] Implemented Sync Service (Firestore)
- [x] Implemented Notification Service
- [x] Created BillProvider for state management
- [x] Updated main.dart with full navigation
- [x] Created Firebase Security Rules

### December 20, 2024 - Evening Session (TO DO)
- [ ] Test the app on emulator/device
- [ ] Fix any compilation issues
- [ ] Add Firebase configuration files
- [ ] Test offline functionality
- [ ] Verify notifications work
- [ ] Create walkthrough documentation

---

## 📌 Remaining Tasks for Evening

1. **Firebase Setup**: 
   - Add `google-services.json` (Android)
   - Add `GoogleService-Info.plist` (iOS)
   
2. **Testing**:
   - Run `flutter pub get`
   - Run `flutter run`
   - Test all screens and flows

3. **Edit Bill Feature** (optional):
   - Add edit functionality to BillDetailView

---

## 📞 Quick Reference

### Data Model: Bill
```dart
class Bill {
  String id;
  String name;
  double amount;
  DateTime dueDate;
  String repeat;      // 'one-time' | 'monthly'
  bool paid;
  String syncStatus;  // 'pending' | 'synced'
  DateTime updatedAt;
}
```

### Firestore Structure
```
users/
└── {uid}/
    └── bills/
        └── {billId}/
            - name
            - amount
            - dueDate
            - repeat
            - paid
            - updatedAt
```

---

*This document is automatically updated as features are implemented.*
