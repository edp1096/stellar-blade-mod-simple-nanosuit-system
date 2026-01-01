Setup for Development
	Install Stellar Blade through Steam
	Install UE4SS mod
		https://github.com/Chrisr0/RE-UE4SS/releases
	Install Lua:
		https://sourceforge.net/projects/luabinaries/files/5.4.2/Tools%20Executables/
		https://www.lua.org/download.html
	Install Luarocks:
		https://luarocks.github.io/luarocks/releases/
		https://luarocks.org/
	Add both of them to System path:
		or:
			Win + R -> sysdm.cpl -> Enter
			Settings -> About System -> Additional system settings
		Go to Advanced tab
		Click Environment Variables
		Select "Path"
		Click "Edit"
	Install dependencies:
		luarocks install lua-path	 0.3.1-2	 --tree=./packages
		luarocks install dkjson		 2.8-2		 --tree=./packages
			inserted space after tabs for Windows terminal to distinguish between args
	For dev also:
		Copy next header files to directory with Lua installation:
			lua.h
			luaconf.h
			lualib.h
			lua.hpp
			lauxlib.h
		Install MinGW GCC compiler:
			https://www.mingw-w64.org/downloads/
			https://github.com/niXman/mingw-builds-binaries/releases
			MinGW-W64-builds
			Pick "msvcrt" version,  like this:  "x86_64-15.2.0-release-win32-seh-msvcrt-rt_v13-rev0.7z"
			Add ".\mingw64\bin" to PATH.
		Install dependencies:
			luarocks install luacheck	 1.2.0-1	 --tree=./packages


Check code for errors:
	./packages/bin/luacheck.bat  --config=./.luacheckrc  --codes  ./scripts  ../shared/Types.lua


TODO:  Packing for Production

	This describes how to prepare a clean, distributable version of the mod
	(without development-only tools and dependencies).

	1) Prepare clean output directory
		Create a new empty directory, for example:
			./dist/SNS/

		Copy mod files into it:
			- scripts/
			- README.txt (optional)
			- any other runtime-required files

		Do NOT copy:
			- .vscode/
			- .idea/
			- .git / .hg
			- .luacheckrc
			- dev scripts or notes


	2) Create packages directory
		Inside the new mod directory create:
			./packages/

		This directory will contain only runtime Lua dependencies.


	3) Install production dependencies
		Install only packages required at runtime
		(using the same Lua version as the game / UE4SS).

		Run from inside the new mod directory:

			luarocks install lua-path  0.3.1-2  --tree=./packages
			luarocks install dkjson    2.8-2    --tree=./packages

		Do NOT install:
			- luacheck
			- luafilesystem (unless explicitly used at runtime)
			- any build / lint / dev-only tools


	4) Verify package layout
		After installation, the directory structure should look like:

			SNS/
				scripts/
				packages/
					bin/
					lib/
					share/
				README.txt (optional)

		The mod must NOT rely on:
			- global LuaRocks installation
			- system-wide Lua packages


	5) Final check (optional but recommended)
		- Launch the game with the mod installed
		- Verify:
			- no missing module errors
			- no references to dev-only tools
			- mod works without Lua / LuaRocks in system PATH


	6) Distribution
		The resulting directory can now be:
			- zipped
			- copied directly into:
				UE4SS/Mods/

		This directory is self-contained and production-ready.
