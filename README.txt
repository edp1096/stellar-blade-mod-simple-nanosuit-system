Info:
	"SNS - Simple Nanosuit System"  is a mod to load custom outfits in format,
		compatible with  "CNS - Custom Nanosuit System"  (https://www.nexusmods.com/stellarblade/mods/1496).

	Its goal is to be a simpler, slightly more stable alternative, allowing users to fix issues by themselves.
		Both mods allow replacing  Eve's:  body, face, ear and eyes accessories;  Adam's, Lily's:  body;  Drone's mesh.
		CNS provides GUI, support for big amount of configs.
			Is closed-source, written in Lua, BP/C++ using Unreal Engine.
			You need to ask mod author in order to add features or fix issues.
		SNS is configured via text file, supports basic replacements, user configs.
			Is open-source, written only in Lua.
			You can do any fixes or implement any features you want.
			But not all "CNS"-compatible mods work well with "SNS",  you should check this by yourself.
			Doesn't support yet "OutfitDatas.Parameters".

	Code is open-source, available on Sourcehut:  https://hg.sr.ht/~vlad0337187/stellar-blade-mod-simple-nanosuit-system
		PRs and any other help are appreciated.

	Please consider the  "CC BY-NC-SA"  license when building upon it.
		This license lets others remix, tweak, and build upon your work non-commercially, as long as they credit you and license their new creations under identical terms.
		License text:  https://creativecommons.org/licenses/by-nc-sa/4.0/
		Author:  vlad0337187

	"SNS - Simple Nanosuit System"  is built to be compatible with  "CNS - Custom Nanosuit System"  mods format.
		Those mods usually have  ".dekcns.json"  files besides  ".utoc", ".ucas", ".pak".
		CNS was created by  "Dekita",  so  ".dekcns.json"  format.
		You can download CNS here:  https://www.nexusmods.com/stellarblade/mods/1496
		CNS Docs:  https://github.com/Dekita/SB-CustomNanosuitSystem-Docs/blob/main/README.md
		They also have a discord server:  https://discord.gg/WyTdramBkm ,  I'm available there from time to time, nick "@vlad0337187".


Installation:
	- install UE4SS
		- https://github.com/Chrisr0/RE-UE4SS/releases
		- so there'll be "<StellarBladeInstallDir>\SB\Binaries\Win64\ue4ss\Mods\" directory present
		- example:  "E:\Games\SteamLibrary\steamapps\common\StellarBlade\SB\Binaries\Win64\ue4ss\Mods\"
	- download "SNS.zip"
	- unpack "SNS.zip" into UE4SS mods directory
		- so there'll be "<StellarBladeInstallDir>\SB\Binaries\Win64\ue4ss\Mods\SNS\" directory present
		- it'll contain "enabled.txt", "sns.settings.json", etc.


Usage:
	- download and place "CNS"-compatible mod into  "<StellarBladeInstallDir>\SB\Content\Paks\~mods\":
		- example:  "E:\Games\SteamLibrary\steamapps\common\StellarBlade\SB\Content\Paks\~mods\"
		- you can create nested folders to structure mods well
	- open ".dekcns.json" file of that mod, copy "UniqueFitID" with it's value
		- example:  "UniqueFitID": "Ines The First Descendant"
	- paste it into "<StellarBladeInstallDir>\SB\Binaries\Win64\ue4ss\Mods\SNS\sns.settings.json"
		- into object in "Replacements" array
		- check "<StellarBladeInstallDir>\SB\Binaries\Win64\ue4ss\Mods\SNS\sns.settings.example.json" for more info
	- load game, see outfit applied
	- you can also edit "<StellarBladeInstallDir>\SB\Binaries\Win64\ue4ss\Mods\SNS\sns.settings.json" any time, then press "F9" to reload
