Great! Let me walk through the `get-current-streak` function with several examples to show how it works:

## The Function:

```clarity
(define-read-only (get-current-streak (user principal))
  (let ((stats (get-user-stats user))
        (current (current-epoch)))
    (if (and (> (get streak-end stats) u0)
             (or (is-eq (get streak-end stats) current)
                 (and (> current u0)
                      (is-eq (get streak-end stats) (- current u1)))))
        (+ (- (get streak-end stats) (get streak-start stats)) u1)
        u0)
  )
)
```

## Example 1: New User (Never Burned)

**Current epoch**: `u5`
**User stats**: `{ streak-start: u0, streak-end: u0, ... }`

```clarity
(> (get streak-end stats) u0)  ;; (> u0 u0) = false
```

Since the first condition is false, the entire `and` is false.
**Result**: `u0` (no current streak)

## Example 2: User Burned Today (Same Epoch)

**Current epoch**: `u5`
**User stats**: `{ streak-start: u3, streak-end: u5, ... }` (burned in epochs 3,4,5)

```clarity
(> (get streak-end stats) u0)  ;; (> u5 u0) = true ✓
(is-eq (get streak-end stats) current)  ;; (is-eq u5 u5) = true ✓
```

The `or` condition is true, so:

```clarity
(+ (- (get streak-end stats) (get streak-start stats)) u1)
= (+ (- u5 u3) u1)
= (+ u2 u1) = u3
```

**Result**: `u3` (3-day streak)

## Example 3: User Burned Yesterday (Continuous)

**Current epoch**: `u7`
**User stats**: `{ streak-start: u4, streak-end: u6, ... }` (burned in epochs 4,5,6)

```clarity
(> (get streak-end stats) u0)  ;; (> u6 u0) = true ✓
(is-eq (get streak-end stats) current)  ;; (is-eq u6 u7) = false
(> current u0)  ;; (> u7 u0) = true ✓
(is-eq (get streak-end stats) (- current u1))  ;; (is-eq u6 u6) = true ✓
```

The `or` condition is true (second part), so:

```clarity
(+ (- u6 u4) u1) = (+ u2 u1) = u3
```

**Result**: `u3` (3-day streak, still active because they burned yesterday)

## Example 4: User Missed Yesterday (Broken Streak)

**Current epoch**: `u10`
**User stats**: `{ streak-start: u5, streak-end: u7, ... }` (last burned in epoch 7)

```clarity
(> (get streak-end stats) u0)  ;; (> u7 u0) = true ✓
(is-eq (get streak-end stats) current)  ;; (is-eq u7 u10) = false
(> current u0)  ;; (> u10 u0) = true ✓
(is-eq (get streak-end stats) (- current u1))  ;; (is-eq u7 u9) = false
```

Both parts of the `or` are false, so the entire condition is false.
**Result**: `u0` (no current streak - it was broken)

## Example 5: Edge Case - Epoch 0

**Current epoch**: `u0`
**User stats**: `{ streak-start: u0, streak-end: u0, ... }` (just burned in epoch 0)

```clarity
(> (get streak-end stats) u0)  ;; (> u0 u0) = false
```

**Result**: `u0` (This is actually a bug! Should return u1)

## Example 6: Edge Case - Epoch 1, Burned in Epoch 0

**Current epoch**: `u1`
**User stats**: `{ streak-start: u0, streak-end: u0, ... }`

```clarity
(> (get streak-end stats) u0)  ;; (> u0 u0) = false
```

**Result**: `u0` (Another bug! Should return u1 if they burned yesterday)

## 🐛 Issues Found:

The function has bugs with epoch 0 handling. Here's a **fixed version**:

```clarity
(define-read-only (get-current-streak (user principal))
  (let ((stats (get-user-stats user))
        (current (current-epoch)))
    (if (or
          ;; Case 1: Burned in current epoch
          (is-eq (get streak-end stats) current)
          ;; Case 2: Burned yesterday (and current > 0 to prevent underflow)
          (and (> current u0)
               (is-eq (get streak-end stats) (- current u1))))
        (+ (- (get streak-end stats) (get streak-start stats)) u1)
        u0)
  )
)
```

This removes the `(> (get streak-end stats) u0)` check that was causing epoch 0 to always return 0.
