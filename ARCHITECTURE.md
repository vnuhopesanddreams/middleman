# How wingchef is put together

## Three Godot ideas you need first

- Scenes are building blocks: a table, a guest, the HUD, a menu. Each is a .tscn file, and scenes can sit inside other scenes.
- Scripts (.gd) give a scene its behaviour.
- Signals are how parts tell each other something happened ("a guest arrived", "the date ended") without needing to know who's listening.

## The screens

    Main menu --PLAY--> Restaurant (a shift) --> End screen --> play again / menu
        |                                          |
        +-- (after a win) Bump screen <------------+

Settings and credits hang off the main menu. The pause menu sits on top of the restaurant.

## Always-on helpers ("autoloads")

These load when the game starts and stay alive on every screen, so anything can use them:

- Settings: volumes and control options, saved to a file
- SaveData: best score, your friend code, friends met, the "bump to play" lock
- Music: plays and fades the background song
- FriendLink: talks to the NFC phone-bumping code (or fakes it on PC)
- Sfx: every sound effect, by event name
- BumpDebug: the F3 / three-finger debug menu (debug builds only)

## The restaurant (where the game happens)

Think of it as a stage, the actors on it, a director, and a screen overlay.

### The stage
- Room: the tiles and the tables.
- RoomRepeater: makes one screen of restaurant feel endless. Sideways it's an illusion: walk off one edge and you're moved to the other. Upwards it really copies the floor 3 times.
- WalkGrid: an invisible grid of tiles marking where people can walk, used to find paths around tables.
- Entrance: 3 spots where guests wait. Exit: where leaving guests walk to and vanish.
- Camera: follows the waiter, and can shake or zoom-punch for effect.

### The actors
- Chelner (the waiter, you): reads taps, drags and keys. Walks, picks guests up, seats them and fixes problems.
- Person (each guest): waits, follows you, sits, leaves. Also handles their own colour (gray, gold, orange, red), sweat, patience at the door and the "!" sign.
- Couple: an invisible pair of two Persons that tracks how happy their date is. It drains happiness when something's wrong, starts problems, and ends the date happily or angrily.
- Table and Seat: where a couple is assigned and sits.
- DateProblem: something going wrong, attached to a guest. Four kinds extend it: bad breath, nervous, spilled drink, fly in soup. Each has its own little minigame.

### The director: ShiftManager
- runs the clock (3 minutes) and the 3 hearts
- decides who walks in next and which table they get
- when a couple ends: happy means points, angry means lose a heart
- ends the shift when time runs out (win) or the hearts run out (lose)

### The screen overlay
- HUD: score, hearts, clock, the "NEW GUEST!" banner, the red edge in the last 30 seconds. Plus off-screen arrows, the problem instructions, the drag joystick and floating "+87" / "NICE!" popups.
- PauseMenu, and ShiftOver (the end screen).

## The life of one guest

1. ShiftManager creates a Couple, gives it a free Table, and spawns the first Person at the door.
2. They wait, gray. After 17s they pulse red, and after 25s they storm out and you lose a heart.
3. You tap them and they follow you, gold. Tap their table and they sit.
4. Their friend arrives later and you seat them too. Now the date is on.
5. Problems pop up with a "!" over them. Tap the guest and do the minigame, or their happiness drains.
6. After 30 seconds the date ends. Happy: hearts float up and you get points. Happiness hit 0: they storm out red and you lose a heart.

## Phone bumping

- Bump screen: shows your code and the bump animation, waits, then plays the celebration and shows the question.
- FriendLink: the game-side bridge to the phone's NFC.
- The Android plugin (android_plugin/, Java): the phone actually swaps the two friend codes over NFC. It's built separately into the .aar files in addons/nfc_friends/.
- BumpQuestions: picks the same question on both phones from the two codes plus the date.
- After a won shift, SaveData sets "needs bump", and the next shift can't start until you bump someone.

## How the parts talk

- Signals carry big events upward. A Couple says "ended", ShiftManager hears it and handles points or hearts, then ShiftManager says "points_changed" / "lives_changed" and the HUD updates.
- Groups handle effects anyone can trigger. Anything can call "camera" -> shake, or "popups" -> pop "NICE!", without holding a reference to them.
- Autoloads are for anything global: Sfx.play("seat"), SaveData.add_friend(...).

## Where things live

    scenes/actors/    waiter, guests, couples
    scenes/objects/   tables, seats, heart burst
    scenes/problems/  the four date problems
    scenes/shift/     the restaurant, ShiftManager, room/grid/camera, SaveData, FriendLink
    scenes/ui/        every menu and screen, HUD bits, Sfx, debug menu, bump stuff
    assets/           art, font, music, sound effects
    android_plugin/   the NFC Java code
