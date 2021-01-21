#Copyright 2021 Phoenix Contact GmbH
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated #documentation files (the "Software"), to deal in the Software without restriction, including without limitation #the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, #and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions #of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED #TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL #THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF #CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER #DEALINGS IN THE SOFTWARE.


#!/bin/bash
#set PATH for command access
#PATH=$PATH:/bin:/usr/bin
#export PATH

# Check for rsync installation
echo ""

if command -v rsync &>/dev/null
then
	echo "Dependencies passed"

else
	echo "Missing rsync installation."
	exit 2
fi

echo "
starting..."

#selectBlk= -1		 #Store block to be copied
activeBlk=-1		 #Store working block being copied to
blkcheck= false
loopcheck= true
inStr=""
starDir=`pwd`		 # Save base directory as variable
hostSize=0.0 			 # Size of block to be copied
currentBlksize=0.0	 # Size of current block

echo "	current dir: " $starDir
while true
do
	#Reset variables
	activeBlk=-1
	blkcheck=false

	#Create a text file of block devices

	blkArr=()
	index=0

	lsblk -rn | grep -v '/\|sda' > blk.txt
	echo "
	Contents of blk.txt: "
	cat blk.txt

	# Read text file and store into array
	echo "
	Processing file into array"

	inFile="./blk.txt"

	while IFS= read -r line
	do
		line=$(cut -b -4 <<< "$line")
		if [ "${line: -1}" == "1" ]
		then
			blkArr+=("$line")
		fi
	done < "$inFile"

	len="${#blkArr[*]}"
	echo -n "Number of detected SD cards: "
	echo $len

	# Create array to keep track of storage devices---------!
	selectArr=($len)
	validArr=()
	echo "Contents of array:"
	echo "${blkArr[*]}"
	#echo "${blkArr[1]}"

	# Mount first block device
	mount /dev/"${blkArr[0]}" dir1
	mount /dev/"${blkArr[1]}" dir2

	echo -e "current directory: "
	pwd
	echo ""

	# Verify PxC storage device via licence file
	for i in $(seq 1 $len)
	do
		#echo "$i"
		let index=($i - 1)
		#echo "$index"
		echo "Contents of ${blkArr[ $index ]}: "
		#if [ "ls dir1/licence | rev | cut -c 1,2,3" == "cxp"]
		if [ '$(ls ./dir1/licence/*.pxc | wc)' >  '0' ]
		then
			echo "	License file found"
			#$validArr[ $index ]+=("1")
			validArr=(${validArr[@]} "1")
		else
			#$validArr[ $index ]+=("0")
			validArr=(${validArr[@]} "0")
			echo "	No license file found."
		fi
	
		echo ""
	done

	umount dir1
	umount dir2

	echo ""
	#echo "Contents of ${blkArr[1]}: "
	#ls dir2/licence
	echo "Outputting valid devices: " 
	for i in $(seq 0 $len ) # iterate with var i  starting at 0 to range len
	do
		#echo "contents of validArr at element $i: ${validArr[i]}"
		if [ "${validArr[i]}" == "1" ]
		then
			echo "	$i) ${blkArr[i]}"
			blkcheck= true
		fi

	done

	# End the program if no valid devices are found
	if [ !$blkcheck == true ]
	then
		echo "No PxC memory cards were found, exiting... "
		#umount dir1
		#umount dir2
		exit 0
	fi

	# Select primary device
	read -p "Please select the device number to be copied: " selectBlk

	#for i in $(seq 1 $len)
	#do
	#	if [ "$validArr[$i - 1]" == "1" ]
	#	then
	#		echo -e "\t$i - ${blkArr[$i - 1]} "
	#	fi
	#done

	# Check to see if the selected number is valid
	if [ "${validArr[ $selectBlk ]}" != "1" ]
	then
		until [ "${validArr[ $selectBlk ]}" == "1" ]; do
			read -p "The selected device number was not a PxC device, try again: " selectBlk
		done
	fi
	mount /dev/"${blkArr[$selectBlk]}" dir1
	echo "	${blkArr[$selectBlk]} mounted to dir1."

	# Get the block size of the main device
	echo `lsblk -o name,size | grep ${blkArr[$selectBlk]} `
	#$hostSize= `lsblk -o name,size | grep ${blkArr[$selectBlk]} | cut -c 10-12  `

	echo -e "new working directory: " 
	pwd

	# Copy the contents of the selected device to the rest
	for i in $( seq 1 $len )
	do
		#echo $i
		let activeBlk=$i-1
		#echo $activeBlk
	
		if [ $activeBlk == i ]
		then
			echo "	skipping duplicate index"
		else
			echo "	Copying the contents of ${blkArr[$selectBlk]} to ${blkArr[i]}"

			mount /dev/"${blkArr[i]}" dir2 #mount the device to get copied to
			rsync -av --exclude '/licence' dir1/ dir2/ #copy everything except licence
			umount dir2 #unmount the device
	
		fi


	done

	# Unmount block device
	umount dir1
	umount dir2
	echo "
	finished.
	"
	echo "Would you like to copy more devices? Yes or No? "
	read inStr
	if [[ $inStr == n* || $inStr == N* ]]
	then
		break
	fi
done

echo "Exiting... 
"