#!/bin/bash

#Do not insert code here

#DO NOT REMOVE THE FOLLOWING TWO LINES
git add $0 >> .local.git.out
git commit -a -m "Lab 2 commit" >> .local.git.out
git push >> .local.git.out || echo

# cycles per second
hertz=$(getconf CLK_TCK)

function check_arguments {


	#If number of arguments is less than 5 it is not valid, exit. 
	if [ "$1" -lt 5 ]; then
		echo "USAGE: "
                echo "$0 {process id} -cpu {utilization percentage} -mem {maximum memory in kB} {time interval}"
                exit
        fi

  #set arbirtray intial values to make cheking easier
  MAX_PERCENTAGE=-1
  MAX_USAGE=-1

  #CPU_THRESHOLD=$4

  #see what is third arg
  if [ $4 == "-mem" ]; then
    MAX_USAGE=$5
  else
    MAX_PERCENTAGE=$4
  fi

  #see if both percente and usage are set in args
  if [ "$1" -gt 6 ]; then
    MAX_USAGE=$6
    TIME_INTERVAL=$8
  else
    TIME_INTERVAL=$7
  fi
}

function init
{

	PID=$1 #This is the pid we are going to monitor

}

#This function calculates the CPU usage percentage given the clock ticks in the last $TIME_INTERVAL seconds
function jiffies_to_percentage {
	
	#Get the function arguments (oldstime, oldutime, newstime, newutime)

	#Calculate the elpased ticks between newstime and oldstime (diff_stime), and newutime and oldutime (diff_utime)
  diff_stime=$4-$2
  diff_utime=$3-$1

	#You will use the following command to calculate the CPU usage percentage. $TIME_INTERVAL is the user-provided time_interval
	#Note how we are using the "bc" command to perform floating point division

	echo "100 * ( ($diff_stime + $diff_utime) / $hertz) / $TIME_INTERVAL" | bc -l
}


#Returns a percentage representing the CPU usage
function calculate_cpu_usage {

	#CPU usage is measured over a periode of time. We will use the user-provided interval_time value to calculate 
	#the CPU usage for the last interval_time seconds. For example, if interval_time is 5 seconds, then, CPU usage
	#is measured over the last 5 seconds


	#First, get the current utime and stime (oldutime and oldstime) from /proc/{pid}/stat

# need to get the 12 and 13th elements in stat

  #check for positiong of utime and stime
  name=$(cat /proc/$PID/stat | awk '{print $2}')
  if [[ name == *")"* ]]; then
    oldutime=$(cat /proc/$PID/stat | awk '{print $14}')
    oldstime=$(cat /proc/$PID/stat | awk '{print $15}')
  else
    oldutime=$(cat /proc/$PID/stat | awk '{print $15}')
    oldstime=$(cat /proc/$PID/stat | awk '{print $16}')
  fi


	#Sleep for time_interval

sleep $TIME_INTERVAL

	#Now, get the current utime and stime (newutime and newstime) /proc/{pid}/stat

  if [[ name == *")"* ]]; then
    newutime=$(cat /proc/$PID/stat | awk '{print $14}')
    newstime=$(cat /proc/$PID/stat | awk '{print $15}')
  else
    newutime=$(cat /proc/$PID/stat | awk '{print $15}')
    newstime=$(cat /proc/$PID/stat | awk '{print $16}')
  fi

	#The values we got so far are all in jiffier (not Hertz), we need to convert them to percentages, we will use the function
	#jiffies_to_percentage


  percentage=$(jiffies_to_percentage $oldutime $oldstime $newutime $newstime)

	#Return the usage percentage
  echo "$percentage" #return the CPU usage percentage
}

function calculate_mem_usage
{
	#Let us extract the VmRSS value from /proc/{pid}/status

# line looks like "VmRSS: {value needed} kb"
mem_usage=$(cat /proc/$PID/status | grep VmRSS | awk '{print $2}')

	#Return the memory usage
	echo "$mem_usage"
}

function notify
{
	#We convert the float representating the CPU usage to an integer for convenience. We will compare $usage_int to $CPU_THRESHOLD
	cpu_usage_int=$(printf "%.f" $cpu_usage)

	#Check if the process has exceeded the thresholds

	#Check if process exceeded its CPU or MEM thresholds. 
  if [ $MAX_PERCENTAGE -gt -1 -a $cpu_usage_int -gt $MAX_PERCENTAGE ] || [ $MAX_USAGE -gt -1 -a $mem_usage -gt $MAX_USAGE ]; then
    exec 3>&2
    exec 2>/dev/null
    COM=$(cat /proc/$PID/cmdline)
    exec 2>&3

    cpu_usage_print=$(printf "%.1f" $cpu_usage)
    message=$'Process Number: '$PID$'\nProcess Name: '$NAME$'\nCommand: '$COM$'\nCPU Usage: '$cpu_usage_print$'%\nMemory Usage: '$mem_usage$' kb'

    #send email and exit to avoid repeated emails
    mail -s 'Memory Usage Exceded' $USER@purdue.edu <<< $message
    exit
  fi
}


check_arguments $# $@

init $1 $@


NAME=$(cat /proc/$PID/stat | awk '{print $2'})

#The monitor runs forever
while [ -n "$(ls /proc/$PID)" ] #While this process is alive
do

	#part 1
  cpu_usage=$(calculate_cpu_usage)

	#part 2
  mem_usage=$(calculate_mem_usage)

	#Call the notify function to send an email to $USER if the thresholds were exceeded
	notify $cpu_usage

done
