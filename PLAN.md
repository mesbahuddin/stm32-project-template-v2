# Plan: Create Your Own Version of the STM32 Project Template

## Context

The user wants to create their own version of the STM32 Project Template repository by Akos Pasztor, giving proper credit. The original git repo has been deleted and a fresh git initialized. The user needs to update all `.md` files and licenses to reflect their ownership while keeping the MIT license and giving proper credit to the original author.

The `plannotator review` command is not installed as a standalone CLI tool on this system — only as an IDE extension.

## Goal

1. Delete current git repo and create a fresh one (done)
2. Update all `.md` files and licenses with proper credits
3. Commit changes to the new git repo

## Plan

### Step 1: Update `LICENSE.md`
- Keep the full MIT text
- Add your name to the copyright line: `Copyright (c) 2024 Akos Pasztor, Mesbah Uddin`

### Step 2: Update `README.md`
- Update the author/credits section in the header

### Step 3: Update `CHANGELOG.md`
- Add an initial entry noting the fork/derivation

### Step 4: Review `docs/cmake-system.md`
- Check for any repo-specific references to the original project

### Step 5: Update `@author` fields in all source files
- Add your name alongside "Akos Pasztor" in all `.c` and `.h` file headers

### Step 6: Commit changes

## Uncertainties

- **Your name** — Mesbah Uddin (confirmed)
- **Whether to keep the project name** — CMake project name is currently `stm32-project-template`
- **Whether to keep all MCAL/HAL files** — These are STM32L496-specific

## Files to modify

| File | Change |
|------|--------|
| `LICENSE.md` | Add your name to copyright line |
| `README.md` | Update author attribution |
| `CHANGELOG.md` | Add initial fork entry |
| `docs/cmake-system.md` | Review for references |
| All `.c`/`.h` file headers | Update `@author` to include your name |

## Verification

- Grep for "Akos Pasztor" to confirm all author references include Mesbah Uddin
- Confirm LICENSE.md has the full original MIT text plus your name
- Verify git status shows clean state after updates
