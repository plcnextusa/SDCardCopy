#Copyright 2021 Phoenix Contact GmbH
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated 
#documentation files (the "Software"), to deal in the Software without restriction, including without limitation 
#the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, 
#and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions #of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
#TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
#THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 
#CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


#!/bin/bash
#set PATH for command access
#PATH=$PATH:/bin:/usr/bin
#export PATH

# Check for rsync installation
echo ""
mkdir dir1 &> /dev/null
mkdir dir2 &> /dev/null
if command -v rsync &>/dev/null
then
	echo "Dependencies passed"

else
	echo "Missing rsync installation."
	exit 2
fi

echo "
starting..."

systemctl stop udisks2	 #Stop automounting service

#selectBlk= -1		 #Store block to be copied
activeBlk=-1		 #Store working block being copied to
blkcheck= false
loopcheck= true
inStr=""
starDir=`pwd`		 # Save base directory as variable
hostSize=0.0 		 # Size of block to be copied
currentBlksize=0.0	 # Size of current block
inchar=""
mastersd=""
mastersize=0


lsblk -rn > blk.txt
#echo "
#Contents of blk.txt: "
#cat blk.txt

echo "Please insert the sd card to be copied now, do NOT remove until the procedure is finished, then press enter."
read -n 1
lsblk -rn > blk2.txt

#check diff of two files, loop if same
while $diffcheck
do
	diff blk.txt blk2.txt &> /dev/null
	if (( $(echo $?)  == 1 ))
	then	#make sure a block device wasnt removed, ruining the list
		if (( $(wc -l blk.txt | awk '{ print $1 }') > $(wc -l blk2.txt | awk '{ print $1 }') ))
		then
			echo "Block device topology has changed, aborting... "
			exit 3
		else
			diffcheck=false
		fi

	else
		echo "No new block devices have been detected, please try again."
		read -n 1
		lsblk -rn > blk2.txt
	fi
done

# Dummy time delay
read -t 1
echo -n "."
read -t 1
echo -n "."
read -t 1
echo ".
"
	
# Store the new block device as a variable
mastersd=$(comm --nocheck-order -3 blk.txt blk2.txt | awk 'END{print $1;}')
mastersize=$(lsblk -bno SIZE /dev/$mastersd | awk '{printf "%.f\n", $1/1024/1024/1024}')
echo "Newly detected storage device: $mastersd size: $mastersize gb"
echo " "

# Confirm the master SD
#	while [[ $inchar:0:1 != 'y' ]]
#	do
#		echo "Is this the SD card to be copied? [yes / no]"
#		read inchar
#	
#		if [ $inchar:0:1 -o 'y' ]
#		then
#			echo "	OK"
#		elif [ $inchar:0:1 -o 'n' ]
#		then
#			echo "	Aborting... "
#			exit 0
#		else
#			read inchar
#		fi
#	done

# Check master SD for pxc license file
echo "Checking master SD card for PxC license file... "
mount /dev/"$mastersd" dir1
if [ '$(ls ./dir1/license/*.pxc | wc)' > '0' ]
then
	echo "	License file found."
else
	echo "	No license file found, aborting..."
	exit 1
fi
umount -l /dev/"$mastersd" dir1 &> /dev/null

echo "	current dir: " $starDir
while true
do
	#Reset variables
	activeBlk=-1
	blkcheck=false
	diffcheck=true
	
	copyblkArr=()
	copysizeArr=()
	#Create a text file of block devices

	blkArr=()
	index=0


	# Wait for copy SD cards to be inserted
	echo "Insert the sd cards you would like to copy to now, then press enter."
	read -n 1

	lsblk -rn > blk3.txt
	diffcheck=true
	while $diffcheck
	do
		diff blk2.txt blk3.txt &> /dev/null
		if (( $(echo $?) == 1 ))	
		then	#make sure a block device wasnt removed, ruining the list
			if (( $(wc -l blk2.txt | awk '{ print $1 }') > $(wc -l blk3.txt | awk '{ print $1 }') ))
			then
				echo "Block device topology has been compromised, aborting... "
				exit 3
			else
				diffcheck=false
			fi

		else
			echo "No new block devices have been detected, please try again."
			read -n 1
			lsblk -rn > blk3.txt
		fi

	done


	# Read text file and store into array
	echo "
	Processing file into array
	"

	#inFile="./blk.txt"

	diff blk2.txt blk3.txt | awk '{ print $2 }' > diff.txt
	lines=diff.txt
	#cat diff.txt
	#cat $lines
	while IFS= read -r line
	#for LINE in $lines
	do 
		#line=$(cut -b -4 <<< "$line")	
		if [ "${line: -1}" == "1" ]
		then
			if [ "$line" == "$masterSD" ]
			then
				echo "Duplicate found, skipping..."
			else
				copyblkArr+=("$line") 	# Add the partition to the copy list
				copysizeArr+=("$(lsblk -bno SIZE /dev/$line | awk '{printf "%.f\n", $1/1024/1024/1024}')")			# Add the size of the partition to the list
			fi
		fi
		#echo $line
	done < "diff.txt"

	len="${#copyblkArr[*]}"
	echo -n "Number of detected SD cards: "
	echo $len
	for i in $(seq 1 $len)
	do
	#	echo $i
		let activeBlk=$i-1
		echo -n "	Block device: ${copyblkArr[$activeBlk]} "
		echo "		Size:  ${copysizeArr[$activeBlk]} gb"
	done

	#echo ${#copyblkArr[*]}
	#for value in "${copyblkArr[@]}"
	#do
	#	echo $value
	#done


	# Create array to keep track of storage devices---------!
	selectArr=($len)
	validArr=()
	for i in $(seq 1 $len)
	do
	
		mount /dev/"${copyblkArr[ $index ]}" dir2
		let index=($i - 1)
		echo ""
		echo "Checking license file of ${copyblkArr[ $index ]}: "
		
		if [ '$(ls ./dir1/licence/*.pxc | wc)' > '0' ]
		then
			echo "	Licence file found"
			validArr=(${validArr[@]} "1")
		else
			echo "	No licence file found"
			validArr=(${validArr[@]} "0")
		fi

		umount -l dir2
	done

	#echo "${validArr[*]}"

	# Copy master SD card to the others
	mount /dev/"$mastersd" dir1
	for i in $( seq 1 $len )
	do
		let index=($i - 1)
		echo ""
		echo "Copying $mastersd to ${copyblkArr[ $index ]}"
		mount /dev/"${copyblkArr[ $index ]}" dir2

	
		rsync -av --exclude '/licence' dir1/ dir2/ # Copy everything except the licence folder
		umount dir2	# unmount the current copy sd
	done	

	umount dir1

	# Ask for loop input
	let inchar="x"
	read -p "Would you like to copy to more SD cards? [y/n] " inchar
	
	while [[ $inchar:0:1 != 'y' ]] || [[ $inchar:0:1 != 'Y' ]]
	do
		if [[ ${inchar:0:1} == 'y' ]] || [[ ${inchar:0:1} == 'Y' ]]
		then
			echo "Please remove the copied SD cards, leave in the master SD card"
			read -t 1
		elif [[ ${inchar:0:1} == 'n' ]] || [[ ${inchar:0:1} == 'N' ]]
		then
			#break
			echo ""
			echo "Operation successful!"
			echo "Exiting... 
			"
			exit 0
		else	
			read -p "Invalid option, copy more SD cards?" inchar
		fi
	done

done

echo ""
echo "Operation successful, you may now remove the master SD card"
echo "Exiting... 
"
