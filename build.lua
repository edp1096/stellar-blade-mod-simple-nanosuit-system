local function _run_in_powershell(cmd)
	return 'powershell -NoProfile -Command "' .. cmd .. '"'
end


local function run(cmd)
	print('> ' .. cmd .. '\n')
	local cmd_in_powershell	= _run_in_powershell(cmd)
	local ok, reason, code	= os.execute(cmd_in_powershell)
	if not ok then
		error('Command failed: ' .. cmd .. ' code: ' .. code .. ' reason: ' .. reason)
	end
end



run('if (Test-Path ./build) { Remove-Item -Recurse -Force ./build }')	-- "rm -R ./build"  fails if dir missing,  no options to fix it
run('mkdir ./build/SNS')
run('mkdir ./build/SNS/packages')
run('cp -R ./scripts ./build/SNS/scripts')
run('cp ./README.txt				 ./build/SNS/')
run('cp ./enabled.txt				 ./build/SNS/')
run('cp ./sns.settings.example.json	 ./build/SNS/')
run('cp ./sns.settings.empty.json	 ./build/SNS/sns.settings.json')
run('cp ./sns.mods_cache.json	     ./build/SNS/sns.mods_cache.json')
run('luarocks install lua-path		 0.3.1-2	 --tree=./build/SNS/packages')
run('luarocks install dkjson		 2.8-2		 --tree=./build/SNS/packages')
run('luarocks install luafilesystem	 1.9.0-1	 --tree=./build/SNS/packages')
run('Compress-Archive -Path ./build/SNS -DestinationPath ./build/SNS.zip')
run('echo \'build success\'')
