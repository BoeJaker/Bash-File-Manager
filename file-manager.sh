#!/bin/bash
#
#	Created: 11.10.16
#	Version: 0.3
#	Status: Alpha - Working
#
#	Title: 
#   	Project Organizer
#	
#	Description: 
#		Aids the user in managing programming files, scripts and schemas
#		See the help function at the bottom of this file for details on use.
#
#	Aim:
#		Increase productivity & ease access to reasouces
#
# Todo
# rearrange functions into: 
#	Backend - performs small system tasks
#	Lists - outputs static lists of directorys, files or functions
#	Filters - outputs lists filtered by filetype name path
#	User interface - allows interaction with the lists
#

#############
# Variables #
#############
stty cols 80

us=$USER
fileTypeExtensions="sh cgi py html php todo txt plan"

projectDirs="/home/$us/bin"
backup_directorys="/media/$us/MULTIBOOT/Backups /media/$us/DATA/Backups"
txtInterpreter=/opt/sublime_text/sublime_text

#######################
# 'Backend' Functions #
#######################

# Deletes everything below $1 in the terminal, then moves the cursor back to $1 
keep_lines(){
	# STATUS # working
	# TDOD # find out if i can hide the cursor during opoeration
	tput cup $1
	count=0	
	while [[ "$count" -le "50" ]] ; do
		tput el && tput cud 1
		((count++))
	done
	tput cup $1
}

# Deletes $1 lines in the terminal
delete_line(){
	# STATUS # working 
	count=0
	while [[ "$count" -le "$1" ]] ; do 
		tput cuu 1 && tput el
		((count++))
	done
}


# Alters immutable state of a file or files. Can also List lockable/unlockable   
lock_files(){
	# STATUS # Working  - complete
	filepath="$1" ; arg="$2" ; direc="/home/boe/bin"
	cd "$direc" ; 
	case "$arg" in 
	"lock")	# locks a file ot list of files
		for f in $filepath ; do
			[[ -f "$filepath" ]] && { sudo chattr +i "$f" && echo -e "$f locked" ; }
		done
		;;
	"unlock") # unlocks a file or list of files
		for f in $filepath ; do
			[[ -f "$filepath" ]] && { sudo chattr -i "$f" && echo -e "$f unlocked" ; }
		done
		;; 
	 "unlk_list") # Lists unlockable files
		unlk=$(lsattr -R 2>/dev/null |  egrep '^.{4}i' | sed 's/^.* //')
		toilet -f pagga "Immutable Files"
		for line in "$unlk" ; do
			unlockable+=("$line")
		done
		select opt in ${unlockable[@]} ; do
			[[ -f "$opt" ]] && { sudo chattr -i "$opt" && echo -e "$opt unlocked"  ; }
		done
		;;
	"lock_list") # Lists lockable files
		lock=$(lsattr -R 2>/dev/null |  egrep -v '^.{4}i' | sed 's/^.* //' | egrep '^./.*/')
		toilet -f pagga "Mutable Files"
		for line in "$lock" ; do
			lockable+=("$line")
		done
		select opt in ${lockable[@]} ; do
			[[ -f "$opt" ]] && { sudo chattr +i "$opt" && echo -e "$opt locked"  ; }
		done
		;;
	esac
	cd ~/
}

# Cuts text based on a target first-line number, file path & delimiter
cut_function(){
	# STATUS # needs testing # smetimes pulls the wrong function
	# TODO # fix newline print error (type newline chars print newlines)
	lineNum=$1 ; targetFile="/$2"  ; delim=$3
	for f in $targetFile ; do 
		end="$(wc -l $f | sed 's/ \/.*//')"
		end=$((end-lineNum))
		end=$(tail -n $end $f | grep -xn "$delim" | head -n 1 | sed 's/:}//') # Finds line number of functions closing }
		end=$((end+lineNum))
		lineNum=$((lineNum-1))
		name="$(echo $extraction | grep "(){" | sed 's/(){//' )"
		extraction=$(sed -n "$lineNum,$end p" "$f")
		echo -e "$extraction\n"
	done
}

# Find the longest common prefix between multiple paths in a project (common parent)
longest_common_prefix(){
	# STATUS # working - complete
    declare -a names
    declare -a parts
    declare i=0

    names=("$@")
    name="$1"
    while x=$(dirname "$name"); [ "$x" != "/" ]
    do
        parts[$i]="$x"
        i=$(($i + 1))
        name="$x"
    done

    for prefix in "${parts[@]}" /
    do
        for name in "${names[@]}"
        do
            if [ "${name#$prefix/}" = "${name}" ]
            then continue 2
            fi
        done
        echo "$prefix"
        break
    done
}

# Generates a directory structure organized by filetype & based in a common parent directory 
make_dir_structure(){
	# STATUS # testing required
	# TODO # touch a index-help.txt file
	commonParent=$1 ; filePath=$2
	filetype=${filePath##*\.}
	name="$(echo ${commonParent%/*})" ; name="$(echo ${name##*/})"
	index="$commonParent/index/"
	structure="$index $index$filetype"
	for dirObject in $structure ; do
		[ -d "$dirObject" ] || mkdir $dirObject &>/dev/null
	done
}


# Wrties compiled data to files
write_index_file(){
	# STATUS # working - complete
	contentsHit=$1 ; ext=$2
	todoIndex="/home/$us/bin/index/$ext"
	indexFile="$todoIndex/$ext-index.txt"

	[[ -d "$todoIndex" ]] || { mkdir "$todoIndex" ; touch "$indexFile" ;}
	lock_files "$indexFile" "unlock" &>/dev/null
	echo -e "$contentsHit" > "$indexFile" 
	lock_files "$indexFile" "lock" &>/dev/null
}

####################
# 'List' functions #
####################

# List all project files
find_projects(){
	# STATUS # working - complete
	for dir in $projectDirs ; do
		find $dir ! -name '.*.save.*' -type f -print
	done
}

# Lists projects based on a user input filetype filter
find_extensions(){
	# STATUS # working - complete
	extension=$1
	for filePath in $( find_projects ) ; do
		ext=${filePath##*\.}
		head -n 1 "$filePath" 2>/dev/null | grep "#!/bin/bash" &>/dev/null && ext="sh"
		if [[ "$ext" == "$extension" ]] ; then
			echo "$filePath"
		fi
	done
}
# cats the contents of all files of a particular filetype
open_extensions(){
	for line in $( find_extensions "$1" ) ; do
		echo -e "\n$line" ; cat "$line"
		echo -e "\n"
	done
}

# Lists all functions from projects of a specified filetype 
find_functions(){
	# STATUS # working - complete
	# TODO # expand function from only recognizing curly brace functions
	extension=$1
	for filePath in $( find_extensions "$extension" ) ; do
		grep -nr "()\s*{" "$filePath" &>/dev/null && echo $filePath
		grep -nr "()\s*{" "$filePath" | sed 's/()\s*{.*//' && echo
	done	
}
# Finds dependancies in functuons
find_dependancies(){
	input="$1"
	for line in "$input" ; do
		echo "Dependancies:"
		echo "$line" | egrep '\$\( .* )' | sed 's/.*\$[(] //' | sed 's/ .*//' # looks for calls to functions and cuts its name from the line
	done
}

# Collect all todos and list by file and line number
collect_todos(){
	# STATUS # working
	# TODO # Make greps more greedy
	# TODO # Add multiline todos to grep
	contentsHit=$( open_extensions 'todo' )
	for filePath in $( find_projects ) ; do
		grep -E -l "^[[:blank:]]*# [Tt][O0][Dd][O0]" "$filePath" &>/dev/null && contentsHit+="\n\n" # adds a newline
		contentsHit+=$(grep -E -l "^[[:blank:]]*# [Tt][O0][Dd][O0]" "$filePath" 2>/dev/null && echo "\n") #adds filepath to the output
		contentsHit+=$(grep -E -nre "^[[:blank:]]*# [Tt][O0][Dd][O0]" $filePath 2>/dev/null | sed "s/\s*#/    #/") # Prints todos
	done
	echo -e "$contentsHit"
}

# Outputs a list of filenames and functions matchng the input query
search_functions(){
# STATUS # working  - complete
	query=$1 ; extension=$2 
	[[ "$extension" ]] || extension="sh"

	for func in $( find_functions $extension ) ; do
		[[ -f "$func" ]] && # If line is a directory label as directory of next functions read
		{
			targetFile="$func"
			if [[ "$targetFile" != "$lastTarget" ]] ; then
				[[ "$funcHit" ]] &&  functionPointer+="$lastTarget \n$funcHit" 
				funcHit=""
			fi

			hit="$(echo $targetFile | grep  $query)"
			[[ "$hit" ]] && grep "$hit" <<< "${menuOptions[@]}"
			[[ "$hit" ]] || fileHit+="$hit \n"
			
			lastTarget=$targetFile 
		} || {
			echo "$func" | grep "$query" &>/dev/null && funcHit+="$func\n"		
		}
	done
	
	echo -e "$functionPointer" 
}


##################
# 'UI' Functions #
##################

# Backup list of project files.
backup_projects(){
	# STATUS # working
	# TODO # backup the file to a recreated path from closest parent in backupdir.
	comnd="$1" ; projects=($( find_projects ))
	verbOut="/dev/tty" ; errOut="/dev/null"

	case "$comnd" in 
		-q) verbOut="/dev/null" ;;
		-v) errOut="/dev/tty"
	esac

	for backupDir in $backup_directorys ; do
		if [ -d "$backupDir" ] ; then
			echo -e "Backup device $backupDir connected"
			sudo chattr -R -i "$backupDir" &>"$errOut"
			~/bin/library/zenity_progress_dialog.sh "${projects[@]}" &>"$errOut" &
			sleep 1
			sucsess=1
			for file in "${projects[@]}" ; do
				cp -v "$file" "$backupDir" &>"$verbOut" || sucsess=0
			done
			[ "$sucsess" -eq "1" ] && 
			{
				echo -e "\nAll projects backed up\n"
				sleep 0.5 && wmctrl -r "Zenity notification" -b add,above &
				zenity --notification --text="All files backed up" &>"$errOut"
			}
			sudo -n chattr -R +i "$backupDir" &>"$errOut"
		else
			echo -e "Backup device $backupDir is not connected"
			# TODO # Add option to backup to alternate directory
		fi
	done
}

# Generate links to documentation
compile_documentation(){
	# STATUS # working
	commonParent=$1
	documentation=$2
	index="$commonParent/index/"
	for document in $documentation ; do
		make_dir_structure "$commonParent" "$document"
		echo "$document"
		name="$(echo ${document##*/})"
		extension=${document##*\.}
		ln -s $document "$index$extension/$name" &>/dev/null
	done
}

# Generates an index filled with links to all files in a project parent
organize_projects(){
	# STATUS # needs rigorous testing
	for filePath in $( find_projects ) ; do
		ext=${filePath##*\.}
		case $ext in
			sh) shFiles+="$filePath " ;;
			py) ;;
			cgi) ;;
			php) ;;
			html) ;;
			txt|todo|plan) txtFiles+="$filePath " ;;
			config) ;;
		esac
	done
	txtPrefix=$( longest_common_prefix $txtFiles )
	make_dir_structure 
	compile_documentation "$txtPrefix" "$txtFiles"
}

# Interprets lists with filepath headers and offers selection & editing via cmd line
post_search_ui(){
	# STATUS # working
	# TODO # fix line deletion after pygmentize
	
	unset functions
	unset menuOptions
	query=$1 ; extension=$2 
	input="$( search_functions $query $extension )" 

	## Input interpreter:
	for line in $input ; do
		line=$(echo -e "$line" | tr -d "\n")
		[[ -f "$line" ]] && { targetFile="$line" ; menuOptions+=("$line") ; } || { functions+=("$line $targetFile") ; }
	done
	echo "${menuOptions[@]}"
	# Menu loops:
	# TODO # Turn menu loops into a general purpose function for file menus
	echo -e "Search query: $query \nFilter: $extension\n\nMatching Functions:\n$input\n"
	read -p "Would you like to open a result? */n" confirm ; delete_line 1 
	[[ "$confirm" != "n" ]] && 
	{	
		repeat=1
		while [[ "$repeat" -ge "1" ]] ; do

			# Matching File Menu
			while [[ "$repeat" -eq "1" ]] ; do 
				keep_lines 0
				echo ; toilet -f pagga "Select a Function"
		    	echo -e "\n####################################\n"
		    	select fileOpt in "${functions[@]}" "Select file" "Quit" ; do
					repeat=3
					case $fileOpt in
						"Select file") repeat=2 ; break  ;;
						"Quit") exit 0 ;;	
						*) repeat=4 ; break ;;
					esac
				done
		    done

		    "repeat=2 ; break,Select file"
		    "exit 0, Quit"
		    # Matching Function Menu
		    while [[ "$repeat" -eq "2" ]] ; do 
		    	keep_lines 0
		    	echo ; toilet -f pagga "Select a File"
				echo -e "\n####################################\n" 
				select fileOpt in "${menuOptions[@]}" "Select function" "Quit" ; do
					repeat=3
					case $fileOpt in
						"Select function") repeat=1 ; break ;;
						"Quit") exit 0 ;;	
						*) break ;;
					esac
				done
		    done
		    
		    # File interaction method menu
		    while [[ "$repeat" -eq "3" ]] ; do
				keep_lines 0
				echo ; toilet -f pagga "Select a Task"
				echo -e "\n###################################\n"
				select subOpt in "Edit" "View" "Lock" "Unlock" "Select file" "Select function" "Quit" ; do
					case $subOpt in 
						"Edit") "$txtInterpreter" "$fileOpt" ;;
						"View") xdotool key ctrl+Shift+x ; pygmentize -g "$fileOpt" ;; # xdo is entering a terminator shortcut
						"Lock") sudo chattr +i "$fileOpt" ;;
						"Unlock") sudo chattr -i "$fileOpt" ;;
						"Select file") repeat=2 ; break ;;
						"Select function") repeat=1 ; break ;;
						"Quit") exit 0 ;;
					esac
				done
			done
			
			# Function interaction method menu
			while [[ "$repeat" -eq "4" ]] ; do 
				keep_lines 0
				echo ; toilet -f pagga "Select a Task"
				echo -e "\n###################################\n"
				select subOpt in "Edit" "View" "Copy" "Select file" "Select function" "Quit" ; do
					
					lineNum=$(echo "$fileOpt" | sed 's/:.*//')
					funcName=$(echo "$fileOpt" | sed 's/[[:space:]]\/.*//' | sed 's/.*://') 
					funcDir=$(echo "$fileOpt" | sed 's/.*[[:space:]]\///')
					echo ; toilet -f pagga "$funcName" #${targetFile##*/}"
					echo -e "\n$funcDir"
					
					case $subOpt in 
						"Edit") "$txtInterpreter" "$fileOpt" ;;
						"View") keep_lines 0
							  	extract="$( cut_function "$lineNum" "$funcDir" "}" )" 
							  	echo -e "$extract" | pygmentize -l bash
							  	find_dependancies "$extract"
							  	;;
						"Copy") keep_lines 0
								extract="$( cut_function "$lineNum" "$funcDir" "}" )" 	
								echo "$extract" | xclip -sel clip 
								echo "Copied to clipboard"  
								read -t 3 ; break 
								;;
						"Select file") repeat=2 ; break ;;
						"Select function") repeat=1 ; break ;;
						"Quit") exit 0 ;;
					esac
				done
			done
		done
	}	
	
}


# Prints a help screen
print_help(){
# STATUS # needs updating
echo -e "\nProject Manager Manual\n\nSyntax = ./projectManager [command] [\$2] [\$3] \n\nCommands:" 
echo "[no command]   - Opens the search interface"
echo "list           - Lists all projects, or you can specify a filetype with [\$1]."
echo "backup         - Creates and updates backups of all projects"
echo "organize       - Creates a symlink index of files"
echo "collect_todo   - Aggregates todos from within project files & writes to todo-index.txt" 
echo "                 & adds them to persistant.todo"
echo "list_functions - lists all functions"
echo "lock           - Locks a files write permission. Specify one or more files with [\$2]"
echo "unlock         - Unlocks a files write permission. Specify one or more files with [\$2]"
echo "search         - Searches files and functions for query [\$2]. Optional filetype filter [\$3]."
echo -e "help           - Displays this page \n"
}


################
# Control Loop #
################
# STATUS # needs updating
com=$1
~/bin/library/install_dependancies "terminator chattr gksu"
keep_lines 0
(( "$#" == "0" )) && 
{
	echo ; toilet -f pagga "Seach Projects"
	echo -e "####################################\n"
	com="search"
	read -p "Enter a search term : " inputA 
	read -p "Enter a filetype filter (optional) : " inputB 
	delete_line 2
} || {
	inputA=$2 ; inputB=$3
	echo -e "####################################\n"
}

for input in "$com" ; do
	case $input in

		# Lists
		list|-l) 
			find_extensions "$inputA" ;;
		list_functions|-lf) 
			find_functions "sh" ;;
		list_todo|-lt) 
			collect_todos ; write_index_file $( collect_todos ) "todo" ;;
		lock_list|-ll) 
			lock_files "null" "lock_list" ;;
		unlk_list|-lu) 
			lock_files "null" "unlk_list" ;;
		
		# Features
		organize|-o) 
			organize_projects ;;
		backup|-b) 
			backup_projects "$inputA" ;;
		search|-s) 
			post_search_ui "$inputA" "$inputB" ;;
		lock|+i) 
			lock_files "$inputA" "lock" ;;
		unlock|-i) 
			lock_files "$inputA" "unlock" ;;
		
		# Help/Errors
		help|-h) cat /home/boe/bin/ProjectManagerManual.txt | zenity --text-info --height=700 --width=700 & ;;
		*) echo -e "Error: $input not a command" 
		   print_help
		  ;;
	esac
done

# TODO # add user interface using zenity

exit 
