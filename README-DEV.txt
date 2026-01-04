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
		luarocks install lua-path		 0.3.1-2	 --tree=./packages
		luarocks install dkjson			 2.8-2		 --tree=./packages
		luarocks install luafilesystem	 1.9.0-1	 --tree=./packages
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


Packing for Production
	This describes how to prepare a clean, distributable version of the mod
		(without development-only tools and dependencies).
	Setup everything in development mode.
	Launch "build.lua" or commands from it.
