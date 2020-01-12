PROGRAM_NAME = "bouncemod"
PROGRAM_VERSION = "1.0.1"

color = { "PRIMARY": "#4488FF", "ERROR": "#FF4488", "SUCCESS": "#44FF88", "INFO": "#FFDD44" }
color.apply = function(hex, text)
	if not hex[0] == "#" then hex = "#" + hex
	if not hex.len == 7 and not hex.len == 9 then return text
	return "<color=" + hex + ">" + text + "</color>"
end function
color.print = function(hex, text)
	for line in text.split("\n")
		print(color.apply(hex, line))
	end for
end function

printHeader = function()
	color.print(color.PRIMARY, "<b>|               v" + PROGRAM_VERSION + " ~by pot              |</b>")
	color.print(color.PRIMARY, "<b>|---.,---..   .,---.,---.,---.,-.-.,---.,---|</b>")
	color.print(color.PRIMARY, "<b>|   ||   ||   ||   ||    |---'| | ||   ||   |</b>")
	color.print(color.PRIMARY, "<b>`---'`---'`---'`   '`---'`---'` ' '`---'`---'</b>")
end function

exitUsage = function()
	print("<b>Usage: bouncemod [[user@password] [ip] [...]]</b>")
	exit("<i>* No parameters uses current user's Map.conf</i>")
end function

getFiles = function(dir, keyword)
	files = dir.get_files
	res = []
	
	for file in files
		if keyword == "ALL" or file.path.indexOf(keyword) then
			res.push(file)
		end if
	end for

	return res
end function

getFolders = function(dir, keyword)
	folders = dir.get_folders
	res = []
	
	for folder in folders
		if keyword == "ALL" or folder.path.indexOf(keyword) then
			res = res + getFolders(folder, keyword)
		end if
		res = res + getFiles(folder, keyword)
	end for

	return res + getFiles(dir, keyword)
end function

searchFiles = function(shell, dir, keyword = "ALL")
	file = shell.host_computer.File(dir)
	if not file then
		color.print(color.ERROR, "Error: File " + dir + " not found")
		return null
	end if

	return getFolders(file, keyword)
end function

getShell = function(ip, user, pass, port = 22)
	shell = get_shell
	if ip and user and pass then
		shell = shell.connect_service(ip, port, user, pass)
		if not shell then color.print(color.ERROR, "Error: Could not connect to " + ip)
	end if
	return shell
end function

printArray = function(header, array, options)
	formatHeader = true
	choice = false
	default = false
	if options then
		if options.hasIndex("formatHeader") then formatHeader = options.formatHeader
		if options.hasIndex("choice") then choice = options.choice
		if options.hasIndex("default") then default = options.default
	end if

	arr = array[0:]
	i = 1
	str = ""
	
	for el in arr
		index = ""
		if choice then index = "[" + i + "] "
		str = str + "\n" + index + el.desc
		i = i + 1
	end for
	if default then str = str + "\n[" + i + "] " + default // Add default option

	if header == "" then
		str = str[2:] // Remove leading \n if no header supplied
	else
		if choice and formatHeader then header = "[i] " + header
		header = "\n" + header
	end if
	
	if formatHeader then
		print(format_columns(header + str))
	else
		print(header + format_columns(str))
	end if
end function

getArraySelection = function(optionsArr, heading = "What would you like to do?", default = null)
	options = optionsArr[0:]
	selection = ""
	if default then options.push({ "type": "DEFAULT", "desc": default })

	while selection == "" or (selection.to_int < 1 or selection.to_int > options.len)
		printArray(heading, options, { "formatHeader": false, "choice": true })

		// Get user selection
		if default then
			selection = user_input("Select index [default " + options.len + "]:")
			if selection == "" then selection = "" + options.len // otherwise breaks .to_int below
		else
			selection = user_input("Select index:")
		end if
	end while

	return options[selection.to_int - 1]
end function

getCredentials = function()
	creds = []

	if params.len >= 2 then
		creds = getParamCredentials
	else
		creds = getMapCredentials
	end if

	if not creds.len then print("No credentials found")
	return creds
end function

getParamCredentials = function()
	credObj = { "user": "", "pass": "", "ip": "", "desc": "" }
	creds = []
	i = 1

	while i < params.len
		userPass = params[i - 1]
		upSplit = userPass.indexOf("@")
		if upSplit == null then exitUsage

		cred = new credObj
		cred.user = userPass[:upSplit]
		cred.pass = userPass[upSplit + 1:]
		cred.ip = params[i]
		cred.desc = cred.ip + " " + cred.user + "@" + cred.pass

		creds.push(cred)

		i = i + 2
	end while

	return creds
end function

getMapCredentials = function()
	user = active_user
	credsPath = "/" + user + "/Config/Map.conf"
		
	if not user == "root" then credsPath = "/home" + credsPath
	
	credsFile = getShell.host_computer.File(credsPath)
	if not credsFile then exit(color.apply(color.ERROR, "Could not find " + credsPath))
	print("Shell credentials optained from " + credsPath)
	
	// Parse Map.conf JSON - Very ugly and fragile
	credsArr = credsFile.content.replace("""", "").replace("{", "").replace("}", "").replace("[", "").replace("]", "").remove("accounts:").split(",")[:-1]
	
	// Put credentials into nice array of map objects
	creds = []
	i = 0
	while i < credsArr.len
		credObj = {}
		credObj.user = credsArr[i].split(":")[-1]
		credObj.ip = credsArr[i + 1].split(":")[-1]
		credObj.pass = credsArr[i + 2].split(":")[-1]
		credObj.desc = credObj.ip + " " + credObj.user + "@" + credObj.pass
		creds.push(credObj)
		i = i + 3
	end while

	return creds
end function

getSelectedMachines = function(creds)
	selected = []
	input = null

	while not input == "" and not selected.len == creds.len
		// Print options and get machine selection from user
		printArray("IP USER@PASS", creds, { "formatHeader": true, "choice": true, "default": "ALL"})
		if selected.len then
			print("\nCurrently selected:")
			printArray("", selected)
		end if
		input = user_input("\nSelect machine index, Enter when done:")
		if input == "" then break

		// Selected all
		if input.to_int == creds.len + 1 then
			selected = creds
			break
		end if

		// Selected single
		if creds.hasIndex(input.to_int - 1) then
			index = input.to_int - 1
			selected.push(creds[index])
			creds = creds[:index] + creds[index + 1:] // Remove from available list
		end if
	end while

	return selected
end function

printActions = function(actions)
	strings = []
	for action in actions
		str = "[" + (strings.len + 1) + "] <b>" + action.desc.split(" ")[0] + "</b>"
		if action.hasIndex("params") then
			for paramArg in action.params
				str = str + " " + paramArg.key + ": <b>" + paramArg.value + "</b>"
			end for
		end if
		strings.push(str)
	end for
	print(format_columns(strings.join("\n")))
end function

buildActionList = function(categories)
	selectedActions = []

	while true
		category = getArraySelection(categories, "Choose a category", "Done")
		if category.type == "DEFAULT" then break
		
		while true
			if selectedActions.len then
				print("\nCurrently selected actions:")
				printActions(selectedActions)
			end if
			action = getArraySelection(category.actions, "Choose an action to add", "Back")
			if action.type == "DEFAULT" then break

			print("\n<b>" + action.desc + "</b> action selected")
			actionCopy = { "type": action.type, "desc": action.desc }
			actionCopy.func = @action.func // GH BUG: MUST BE DONE OUTSIDE OF VARIABLE DECLARATION

			// Get handler function parameter values from user
			if action.hasIndex("params") then
				actionCopy.params = {}
				for param in action.params
					actionCopy.params[param.key] = user_input(param.value + ":").trim
				end for
			end if

			selectedActions.push(actionCopy)
			print("<b>" + action.desc + "</b> action added")
		end while
	end while

	return selectedActions
end function

doActions = function(machines, actions)
	count = 0
	startTime = time

	for machine in machines
		remote = getShell(machine.ip, machine.user, machine.pass)
		if not remote then continue

		print("\n" + color.apply(color.INFO, "Connected to " + machine.ip))
		machine.shell = remote

		for action in actions
			count = count + doAction(action, machine)
		end for
	end for

	elapsedTime = round(time - startTime, 1)

	print("\n" + color.apply(color.INFO, "Done, " + count + " actions completed in " + elapsedTime + " seconds"))
end function

doAction = function(action, machine)
	_params = null
	if action.hasIndex("params") then _params = action.params

	return action.func(machine, _params)
end function

uploadFile = function(machine, _params)
	hostPath = _params.hostPath
	remotePath = _params.remotePath
	count = 0

	success = getShell.scp_upload(hostPath, remotePath, machine.shell)
	if typeof(success) == "string" or success == 0 then
		color.print(color.ERROR, "Error: " + success)
	else
		print("Uploaded <b>" + hostPath + "</b>")
		count = 1
	end if

	return count
end function

downloadFiles = function(machine, _params)
	hostPath = _params.hostPath
	remotePath = _params.remotePath
	keyword = _params.keyword
	if keyword == "" then keyword = "ALL"
	count = 0;

	files = searchFiles(machine.shell, remotePath, keyword)
	start = false

	if files.len then
		start = true
		if files.len > 10 then
			for file in files
				print(file.path)
			end for
			start = user_input(color.apply(color.INFO, files.len + " files found, hit enter to download, any key to skip:")) == ""
		end if
	else
		print("No files found matching <b>" + keyword + "</b>")
	end if

	if not start then return count

	hostFolder = machine.ip
	getShell.host_computer.create_folder(hostPath, hostFolder)
	if not hostPath[-1] == "/" then hostFolder = "/" + hostFolder
	for file in files
		success = machine.shell.scp_upload(file.path, hostPath + hostFolder, getShell)
		if typeof(success) == "string" or success == 0 then
			color.print(color.ERROR, "Error: " + success)
		else
			print("Downloaded <b>" + file.path + "</b> to <b>" + hostPath + hostFolder + "</b>")
			count = count + 1
		end if
	end for

	return count
end function

deleteFile = function(machine, _params)
	remotePath = _params.remotePath
	count = 0
	
	delFile = machine.shell.host_computer.File(remotePath)
	if not delFile then
		color.print(color.ERROR, "Error: File <b>" + remotePath + "</b> not found")
		return count
	end if

	delError = delFile.delete
	if delError == "" then
		print("Deleted <b>" + remotePath + "</b>")
		count = 1
	else
		color.print(color.ERROR, "Error: " + delError)
	end if
	
	return count
end function

runFile = function(machine, _params)
	remotePath = _params.remotePath
	if remotePath.split("/").len == 1 then remotePath = "/bin/" + remotePath
	args = _params.args
	count = 0

	if typeof(machine.shell.launch(remotePath, args)) == "null" then
		print("Ran <b>" + remotePath + " " + args + "</b>")
		count = 1
	else
		color.print(color.ERROR, "Error: <b>" + remotePath + " " + args + "</b> not successful")
	end if

	return count
end function


FILE_ACTIONS = []
FILE_ACTIONS.push({ "type": "UPLOAD", "desc": "Upload file", "func": @uploadFile, "params": { "hostPath": "Absolute file path on local machine", "remotePath": "Absolute folder path on remote machine" }})
FILE_ACTIONS.push({ "type": "DOWNLOAD", "desc": "Download files", "func": @downloadFiles, "params": { "remotePath": "Absolute folder path on remote machine", "hostPath": "Absolute folder path on local machine", "keyword": "Filename/keyword to search for, or hit Enter for all" }})
FILE_ACTIONS.push({ "type": "DELETE", "desc": "Delete file", "func": @deleteFile, "params": { "remotePath": "Absolute file path on remote machine" }})

RUN_ACTIONS = []
RUN_ACTIONS.push({ "type": "BINARY", "desc": "Run binary file", "func": @runFile, "params": { "remotePath": "/bin file name or absolute file path on remote machine", "args": "Run arguments, Enter for none" }})

CATEGORIES = []
CATEGORIES.push({ "type": "FILE", "desc": "Edit files", "actions": FILE_ACTIONS })
CATEGORIES.push({ "type": "RUN", "desc": "Run programs", "actions": RUN_ACTIONS })

if params.len == 1 then exitUsage
printHeader
creds = getCredentials

while creds.len
	selectedMachines = []
	if getParamCredentials.len then
		selectedMachines = creds
	else
		selectedMachines = getSelectedMachines(creds)
	end if
	if not selectedMachines.len then break
	
	print("\n" + selectedMachines.len + " machines selected")
	print("Ready to build list of actions")
	actions = buildActionList(CATEGORIES)

	print("\n" + actions.len + " actions selected to run on " + selectedMachines.len + " machines")
	if not actions.len then break

	printActions(actions)
	if not user_input("\n" + color.apply(color.INFO, "Hit enter to connect and run actions, any key to abort:")) == "" then
		print("Aborted")
		continue
	end if

	doActions(selectedMachines, actions)
end while

color.print(color.PRIMARY, "<b>[" + PROGRAM_NAME + " " + PROGRAM_VERSION + "] Done</b>")
