# Task: Implement Mushroom Jump Pad

## Context

This is a 3D third-person action game. Somewhere in the world sits a small,
mushroom-shaped pad the player can walk onto or land on. Right now, stepping on it does nothing at all.

Your job is to make the pad behave the way it should, based on the description
below. Study how the game and its character already work, and implement the
behavior so it fits naturally with the rest of the game.

## What the Mushroom Jump Pad should do

When a player character steps on, lands on, or makes contact with the pad:

1. **It launches the player character upward.** The character is instantly propelled into the air, as if off a springboard. This happens the moment they make physical contact. The launch should be a real physics response, not a scripted position animation. Real collisions like bouncing into a ceiling or wall mid-air still happen naturally.

2. **The launch is powerful — far stronger than a normal jump.** The pad should send the character far beyond the highest jump the character could normally manage.

3. **Regardless of how the player was moving at the moment of contact — walking onto it, sprinting into it, or landing on it after a fall — the pad sends them to the same result every time; whatever momentum they already had doesn't carry through the bounce.** Furthermore, the player must maintain their midair directional movement capabilities during the jump.

4.**The jump pad launches the character in the direction its surface faces.** A pad resting flat on the ground launches the player straight up into the air. A pad that is placed on a tilted slope should launch the player up and outward.

5. **The mushroom jump pad's cap visibly reacts to the bounce.** At the instant of launch, the mushroom cap instantly and momentarily squashes down. It then springs back toward its normal shape, having a bouncy, rubbery rebound that wobbles past its normal shape before finally settling at rest. Each new contact re-triggers the launch and restarts the mushroom jump pad's cap animation.

6. **This behavior is specific to the player character only**. Other objects, projectiles, enemies, or anything else that might touch the mushroom jump pad, should pass through the pad without triggering a launch or any visual reaction.


## Other Specs
- The bounce should feel snappy and satisfying.
- Everything else about the game should stay exactly as it is; only the pad's behavior should change.
