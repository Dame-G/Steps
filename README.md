# Dungeon Delver Roguelite

## Game Loop

1. Character Creation
   - Choose race, class, and name
   - Each character has 5 lives
   - Races have unique passive abilities
   - Classes have unique ability progressions and combat mechanics
2. Enter Game Lobby
   - Manage storage (shared between characters, items persist after death)
   - Choose Game Mode Portal:
     - Dungeon Floor
     - Colosseum
     - Arena
   - Interact with Stations:
     - Anvil (crafting/upgrading)
     - Brewing Pot (foods/potions)
   - Visit Shops:
     - General Shop (sells player-sold items)
     - Global Auction
   - Check Leaderboards
3. Enter Game Mode
   - Dungeon Floor:
     - Explore procedurally generated rooms
     - Fight mobs and bosses
     - Collect loot and experience
     - Exit or continue to the next floor
   - Colosseum:
     - Fight waves of mobs and bosses
     - Collect rewards and experience
     - Exit or continue to the next wave
   - Arena:
     - Engage in PvP battles
     - Spectate and bet on fights
     - Customize fight matchups and conditions
4. Return to Game Lobby
   - Store acquired loot
   - Level up and allocate skill points
   - Craft and upgrade items
   - Buy and sell items
   - Repeat steps 3-4 until character death or player quits
5. Character Death
   - Lose all lives
   - Character permanently destroyed
   - Items in storage persist for future characters

## Progression

- Leveling Up:
  - Level reflects the highest floor reached
  - Each level grants skill points
  - Skill points can be allocated in class-specific skill tree
    - Passive skills: Enhance character attributes and abilities
    - Active skills: Unlock new abilities or improve existing ones
- Items:
  - Acquired from mob drops, chests, bosses, and other players
  - Can be sold to the General Shop for a fixed price
  - Can be auctioned to other players in the Global Auction
- Crafting:
  - Ingredients obtained from mob drops and chests
  - Used at the Anvil to craft and upgrade equipment
  - Used at the Brewing Pot to create foods and potions
- Gold:
  - Earned by selling items to the General Shop
  - Used to purchase items from the General Shop and Global Auction
  - Used to reset skill points

## Mechanics

- Skills:
  - Each class has a unique skill tree
  - Passive skills enhance character attributes (e.g., increased health, damage, critical chance)
  - Active skills are triggered abilities (e.g., special attacks, buffs, debuffs)
  - Skill points are earned upon leveling up and can be allocated in the skill tree
- Stations:
  - Anvil:
    - Used to craft and upgrade equipment using ingredients
    - Higher-level ingredients and recipes unlock at higher dungeon levels
  - Brewing Pot:
    - Used to create foods and potions using ingredients
    - Foods provide temporary buffs (e.g., increased stats, regeneration)
    - Potions provide instant effects (e.g., healing, mana restoration)
- Dungeon Floor:
  - Procedurally generated rooms, scaling in difficulty with each level
  - Mobs drop gold, crafting ingredients, and occasionally items
  - Secret rooms, bosses, and chests can spawn with higher rarity chances in deeper levels
  - Defeating the floor boss grants a level-up, a chest, and an exit portal
  - Failing to exit the dungeon counts as a death
  - Party sizes for dungeons increase at higher levels
  - Dungeon is a DANGER ZONE where other players and mobs can attack you
- Colosseum:
  - Wave-based combat with bosses every 5 waves, representing a floor increase
  - 30-second break after each boss
  - Difficulty and rewards increase after each boss (chest drops, mob loot)
  - Faster leveling compared to Dungeon Floor, but with less overall loot
  - Exiting the Colosseum requires sacrificing a life
- Arena:
  - PvP mode where players can battle each other
  - Players can bet on or against other players and spectate fights
  - Customizable fight matchups (1v1, 2v2, 3v3, FFA, etc.)
  - Customizable fight conditions (to the death, first hit, 10% health, etc.)
- Storage:
  - Limited shared storage space persists across characters
  - Items in storage are not lost upon character death