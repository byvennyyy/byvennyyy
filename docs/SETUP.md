# Setup: getting this project into your open Roblox Studio place

This repo is a [Rojo](https://rojo.space) project: all game code lives in `src/` and syncs into
Studio. Your animal and egg models stay in Studio (they are not in git).

## 1. Tools (one-time, on your PC)

1. Install [Rokit](https://github.com/rojo-rbx/rokit) and run `rokit install` in the repo folder.
   This installs the pinned `rojo`, `luau-lsp` and `stylua` from `rokit.toml`.
2. In Studio, install the Rojo plugin: run `rojo plugin install` from the repo folder, or get it
   from the Creator Store.
3. Optional but recommended: the Rojo and Luau Language Server VS Code extensions.

## 2. Import the animal bundle

1. Unzip `RBXM Animal Empire Bundle.zip`. Insert the `.rbxm` files into Studio (right-click
   ReplicatedStorage > Insert from File, or drag them into the viewport).
2. Make the tree look exactly like this (case-sensitive):

```
ReplicatedStorage
└─ Assets
   ├─ Animals
   │  ├─ Animal          <- the folder with Aardvark, Akita, Albatross ... Yak
   │  └─ BaseAnimals     <- the folder with ARCHAEOPTERYX ... Spinosaurus
   └─ Eggs               <- see step 3
```

   The code looks up an animal by its exact model name inside those two folders (see
   `src/ReplicatedStorage/Shared/Config/Biomes.luau`, field `animal`). If a model is missing the
   game still runs with a blocky placeholder, so you can import gradually.

3. Each animal model needs a `PrimaryPart`. Select a model, and in Properties set PrimaryPart to
   its root/torso part if it is empty. Animations: if the model has an `Animator` (inside a
   `Humanoid` or `AnimationController`) and `Animation` objects named `Run`, `Walk` or `Idle`
   anywhere inside it, the chaser plays them. Otherwise it gets a procedural bob so it still looks
   alive.

## 3. Import the egg pack

1. Unzip `EggPack1.0.zip`, insert the models and put them under `ReplicatedStorage/Assets/Eggs`.
2. Note the model names, then in `Biomes.luau` set `eggModel = "ExactModelName"` on each biome.
   Any biome with `eggModel = nil` gets a procedurally generated egg tinted with the biome
   palette, so nothing breaks while you decide which egg goes where.
3. For the hatch animation the code pops off a child named `Top` if the egg model has one, and
   otherwise scales the whole egg down while the animal pops up.

Handy command-bar snippet to list what you imported (View > Command Bar in Studio):

```lua
for _, m in game.ReplicatedStorage.Assets.Eggs:GetChildren() do print(m.Name, m:IsA("Model") and m.PrimaryPart) end
```

## 4. Sync the code into your open place

From the repo folder:

```
rojo serve
```

Then in Studio click the Rojo plugin button and **Connect**. The `src/` tree appears under
ReplicatedStorage.Shared, ServerScriptService.Server and StarterPlayer.StarterPlayerScripts.Client.
Rojo only manages those paths, so your models, terrain and lighting are untouched.

Press Play. With `Workspace/Obby` empty, the server generates all 20 biomes (200 greybox stages)
on the grid defined in `GameConfig.Grid`, complete with checkpoints, paths and egg pedestals. Hand
built stages replace generated ones one at a time (see `docs/GDD.md`, "Level authoring contract").

Alternative without the plugin: `rojo build default.project.json -o AnimalObby.rbxl` produces a
standalone place file you can open and then paste your asset folders into.

## 5. Checks before committing

```
scripts/check.sh          # rojo sourcemap + luau-lsp strict typecheck + stylua
tests/run.sh              # unit tests for the pure engine modules (needs the luau CLI)
```

## 6. Running Claude Code on your PC instead of the cloud

The cloud session cannot see your `C:\Users\...` files or your open Studio. To continue locally:

1. Install Claude Code on Windows (PowerShell): `irm https://claude.ai/install.ps1 | iex`
   (or `winget install Anthropic.ClaudeCode`).
2. Clone this repo and check out the branch, with a clean working tree.
3. In that folder run `claude --teleport` and pick this session (or use **Open in > Terminal**
   on the session at claude.ai/code to copy the exact command). The conversation continues locally
   with full access to your files.
4. To let Claude read and edit the open Studio place directly, install Roblox's official
   Studio MCP server (https://github.com/Roblox/studio-rust-mcp-server, download the Windows
   release, run the installer with Studio closed) and register it:
   `claude mcp add --transport stdio roblox-studio -- "C:\path\to\rbx-studio-mcp.exe" --stdio`,
   then restart Studio and Claude Code. `claude mcp list` should show it connected.
