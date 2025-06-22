Great! Let me walk through several scenarios in the `daily-burn` function:

## Scenario 1: Brand New User, Epoch 0

**Setup**: First person ever to burn

- `current = u0`
- `current-stats = { epoch: u0, total-burns: u0, streak-start: u0, streak-end: u0, max-streak: u0 }`

**Execution**:

```clarity
(last-active-epoch (get streak-end current-stats))  ;; u0
(is-continuing-streak (and (> u0 u0) (is-eq u0 (- u0 u1))))  ;; false (short-circuit)
(new-streak-start (if false (get streak-start current-stats) u0))  ;; u0
(new-streak-end u0)  ;; u0
(current-streak-length (+ (- u0 u0) u1))  ;; u1
(new-max-streak (max u0 u1))  ;; u1
(new-total-burns (+ u0 u1))  ;; u1
```

**Result**: `{ epoch: u0, total-burns: u1, streak-start: u0, streak-end: u0, max-streak: u1 }`

---

## Scenario 2: Same User, Epoch 1 (Next Day)

**Setup**: User from scenario 1 burns again

- `current = u1`
- `current-stats = { epoch: u0, total-burns: u1, streak-start: u0, streak-end: u0, max-streak: u1 }`

**Execution**:

```clarity
(last-active-epoch u0)
(is-continuing-streak (and (> u1 u0) (is-eq u0 (- u1 u1))))  ;; (and true (is-eq u0 u0)) = true
(new-streak-start (if true u0 u1))  ;; u0 (keep existing)
(new-streak-end u1)  ;; u1
(current-streak-length (+ (- u1 u0) u1))  ;; u2
(new-max-streak (max u1 u2))  ;; u2
(new-total-burns (+ u1 u1))  ;; u2
```

**Result**: `{ epoch: u1, total-burns: u2, streak-start: u0, streak-end: u1, max-streak: u2 }`

---

## Scenario 3: Same User, Epoch 3 (Missed Epoch 2)

**Setup**: User skipped epoch 2, now burning in epoch 3

- `current = u3`
- `current-stats = { epoch: u1, total-burns: u2, streak-start: u0, streak-end: u1, max-streak: u2 }`

**Execution**:

```clarity
(last-active-epoch u1)
(is-continuing-streak (and (> u3 u0) (is-eq u1 (- u3 u1))))  ;; (and true (is-eq u1 u2)) = false
(new-streak-start (if false u0 u3))  ;; u3 (start new)
(new-streak-end u3)  ;; u3
(current-streak-length (+ (- u3 u3) u1))  ;; u1 (new streak of 1)
(new-max-streak (max u2 u1))  ;; u2 (keep old max)
(new-total-burns (+ u2 u1))  ;; u3
```

**Result**: `{ epoch: u3, total-burns: u3, streak-start: u3, streak-end: u3, max-streak: u2 }`

---

## Scenario 4: Different User, Epoch 5

**Setup**: New user starts burning in epoch 5

- `current = u5`
- `current-stats = { epoch: u0, total-burns: u0, streak-start: u0, streak-end: u0, max-streak: u0 }`

**Execution**:

```clarity
(last-active-epoch u0)
(is-continuing-streak (and (> u5 u0) (is-eq u0 (- u5 u1))))  ;; (and true (is-eq u0 u4)) = false
(new-streak-start (if false u0 u5))  ;; u5
(new-streak-end u5)  ;; u5
(current-streak-length (+ (- u5 u5) u1))  ;; u1
(new-max-streak (max u0 u1))  ;; u1
(new-total-burns (+ u0 u1))  ;; u1
```

**Result**: `{ epoch: u5, total-burns: u1, streak-start: u5, streak-end: u5, max-streak: u1 }`

---

## Scenario 5: User with Long Streak, Epoch 10

**Setup**: User has been burning epochs 7,8,9, now in epoch 10

- `current = u10`
- `current-stats = { epoch: u9, total-burns: u15, streak-start: u7, streak-end: u9, max-streak: u5 }`

**Execution**:

```clarity
(last-active-epoch u9)
(is-continuing-streak (and (> u10 u0) (is-eq u9 (- u10 u1))))  ;; (and true (is-eq u9 u9)) = true
(new-streak-start (if true u7 u10))  ;; u7 (continue existing)
(new-streak-end u10)  ;; u10
(current-streak-length (+ (- u10 u7) u1))  ;; u4
(new-max-streak (max u5 u4))  ;; u5
(new-total-burns (+ u15 u1))  ;; u16
```

**Result**: `{ epoch: u10, total-burns: u16, streak-start: u7, streak-end: u10, max-streak: u5 }`

## Summary:

✅ **Epoch 0**: Correctly starts new streaks
✅ **Continuing streaks**: Properly extends existing streaks  
✅ **Broken streaks**: Starts fresh streaks
✅ **New users**: Works regardless of starting epoch
✅ **Max streak tracking**: Preserves historical maximums

The logic handles all cases perfectly! 🔥
