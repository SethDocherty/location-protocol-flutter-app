# Hide Offchain Operations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide the "Offchain Operations" section in `HomeScreen` when no wallet is connected.

**Architecture:** Wrap the "Offchain Operations" header and buttons in a conditional block using `walletProvider.isConnected`.

**Tech Stack:** Flutter, Provider.

---

### Task 1: Update HomeScreen UI

**Files:**
- Modify: `lib/screens/home_screen.dart:91-96`

- [ ] **Step 1: Apply the conditional check**
Modify `lib/screens/home_screen.dart` to wrap the offchain operations section.

```dart
// lib/screens/home_screen.dart around line 91

            // --- Offchain Operations (only when connected) ---
            if (walletProvider.isConnected) ...[
              _SectionHeader('Offchain Operations'),
              _buildSignOffchainButton(context, walletProvider),
              const SizedBox(height: 8),
              _buildVerifyButton(context),
              const SizedBox(height: 24),
            ],
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat(ui): hide offchain operations when no wallet connected"
```
