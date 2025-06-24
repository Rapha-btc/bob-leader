Based on your requirements, here's how to adapt the burn-to-play contract for PEPE with the competitive reward system:Here's your adapted PEPE burn-to-play competition contract with the key changes:

## Key Features Implemented:

1. **Daily Competition Cycles**: 144 block epochs (~24 hours)

2. **Competitive Burning**: Users can burn any amount of PEPE tokens multiple times per epoch, building up their total

3. **Reward Distribution**:

   - **90%** to the highest burner (winner)
   - **9.31%** permanently burned to cant-be-evil.stx
   - **0.69%** taken as contract fee

4. **Safety Mechanisms**:

   - Minimum 2 participants required
   - Rollover function for insufficient participation
   - Prevents double settlement

5. **Game Mechanics**:
   - Users can increase their burn amount during the epoch
   - Real-time leaderboard tracking
   - Late-game strategy enabled (burn more near epoch end)

## Key Functions:

- `burn-to-compete(amount)` - Main function to participate
- `settle-epoch(epoch)` - Distribute rewards after epoch ends
- `rollover-epoch(epoch)` - Handle epochs with <2 participants
- `get-current-competition-info()` - Real-time status for UI

## Usage Flow:

1. Users call `burn-to-compete` with PEPE amount during the epoch
2. They can call it multiple times to increase their total
3. After 144 blocks, anyone can call `settle-epoch` to trigger payout
4. Winner gets 90%, tokens get burned, cycle repeats

This creates the "eBay bidding war" dynamic you wanted, where participants keep upping each other until the epoch ends, with permanent supply reduction built in!
