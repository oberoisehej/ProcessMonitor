#!/bin/bash

#Do not insert code here

#DO NOT REMOVE THE FOLLOWING TWO LINES
git add $0 >> .local.git.out
git commit -a -m "Lab 2 commit" >> .local.git.out
git push >> .local.git.out || echo

# cycles per second
hertz=$(getconf CLK_TCK)

#Total memory in the system
TOTALMEM=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')

#arrays for calculations
declare -a cur_processes
declare -a oldutime
declare -a oldstime
declare -a newutime
declare -a newstime
declare -a cpuUsage
declare -a memUsage
declare -a topNIndex
declare -a topCPUUsage
declare -a topMemUsage


#function to extract arguments
function check_arguments () {

    #default values
    numProcesses=20
    timeInterval=10
    all=0
    i=0
    isProc=0
    isTime=0
    measure=0 #0 = cpu, 1 = mem

    #extracting...
    for i in $@
    do
      if [ $isProc == 1 ]; then
        numProcesses=$i
        isProc=0
      fi
      if [ $isTime == 1 ]; then
        timeInterval=$i
        isTime=0
      fi
      if [ $i == '-p' ]; then
        isProc=1
      elif [ $i == '-t' ]; then
        isTime=1
      elif [ $i == '-a' ]; then
        all=1
      elif [ $i == '-c' ]; then
        measure=0
      elif [ $i == '-m' ]; then
        measure=1
      fi
     done

     if [ $numProcesses == 0 ]; then
      numProcesses=20
     fi
     if [ $timeInterval == 0 ]; then
      timeInteval=10
    fi
    #echo $numProcesses $timeInterval $all
}


function header () {

  #Making the first line of the header
  b=0
  for i in $(cat /proc/uptime)
  do
    if [ $b == 0 ]; then
      UPTIME=$i
    fi
    let b=b+1
  done

  #Formating uptime appropriatly
  UPTIME=$(printf "%.f" $UPTIME)

  PRINT_UPTIME=""
  #1 day = 86400 seconds, 1 hour = 3600 seconds, 1 minute = 60 seconds
  if [ $UPTIME -gt 86400 ]; then
    let DAYS=$((UPTIME/86400))
    PRINT_UPTIME=$DAYS" days, "
    let UPTIME=UPTIME-$((DAYS*86400))
  fi
  if [ $UPTIME -gt 3600 ]; then
    let HOURS=$((UPTIME/3600))
    PRINT_UPTIME=$PRINT_UPTIME$HOURS":"
    let UPTIME=UPTIME-$((HOURS*3600))
  fi
  if [ $UPTIME -gt 60 ]; then
    let MINS=$((UPTIME/60))
    PRINT_MINS=$MINS
    if [ $MINS -lt 10 ]; then
      PRINT_MINS="0"$MINS
    fi
    PRINT_UPTIME=$PRINT_UPTIME$PRINT_MINS
    let UPTIME=UPTIME-$(($MINS*60))
  fi

  USERS=$(users |wc -w)

  b=0
  for i in $(cat /proc/loadavg)
  do
    if [ $b == 0 ]; then
      LOAD_AVERAGE=$i
    fi
    if [ $b == 1 -o $b == 2 ]; then
      LOAD_AVERAGE="$LOAD_AVERAGE, $i"
    fi
    let b=b+1
  done

  line1="procmon - $(date +"%T") up $PRINT_UPTIME, $USERS users, load average: $LOAD_AVERAGE"

  #Making the second line of the header

  SLEEPING=0
  RUNNING=$(cat /proc/stat | grep running | grep -o .$)
  ZOMBIE=0
  STOPPED=0
  exec 3>&2
  exec 2>/dev/null

  for id in $(ls /proc |egrep [0-9]+)
  do
    STATUS=$(cat /proc/$id/status | grep State | awk '{print $3}') 
    if [[ $STATUS == "(sleeping)" ]]; then
      let SLEEPING=SLEEPING+1
    else
      if [[ $STATUS == "(stopped)" ]]; then
        let STOPPED=STOPPED+1
      else
        if [[ $STATUS == "(zombie)" ]]; then
          let ZOMBIE=ZOMBIE+1
        fi
      fi
    fi
  done
  NUMTASKS=$(ls /proc |egrep [0-9]+ | wc -l)
  exec 2>&3
  line2="Tasks: $NUMTASKS, $RUNNING running, $SLEEPING sleeping, $STOPPED stopped, $ZOMBIE zombie"

  #make the third line of the header

  #getting values from files
  CPU=$(cat /proc/stat | grep -m1 cpu)
  US=$(echo $CPU | awk '{print $2}')
  NI=$(echo $CPU | awk '{print $3}')
  SY=$(echo $CPU | awk '{print $4}')
  IDLE=$(echo $CPU | awk '{print $5}')
  WA=$(echo $CPU | awk '{print $6}')
  HI=$(echo $CPU | awk '{print $7}')
  SI=$(echo $CPU | awk '{print $8}')
  ST=$(echo $CPU | awk '{print $9}')
  let TOTAL=US+NI+SY+IDLE+WA+HI+SI+ST

  #turning to percentages
  TOTAL=$(bc -l <<< "$TOTAL/100")
  US=$(bc -l <<< "$US/$TOTAL")
  NI=$(bc -l <<< "$NI/$TOTAL")
  SY=$(bc -l <<< "$SY/$TOTAL")
  IDLE=$(bc -l <<< "$IDLE/$TOTAL")
  WA=$(bc -l <<< "$WA/$TOTAL")
  HI=$(bc -l <<< "$HI/$TOTAL")
  SI=$(bc -l <<< "$SI/$TOTAL")
  ST=$(bc -l <<< "$ST/$TOTAL")

  #format to 1 dp
  US=$(printf "%.1f" $US)
  NI=$(printf "%.1f" $NI)
  SY=$(printf "%.1f" $SY)
  IDLE=$(printf "%.1f" $IDLE)
  WA=$(printf "%.1f" $WA)
  HI=$(printf "%.1f" $HI)
  SI=$(printf "%.1f" $SI)
  ST=$(printf "%.1f" $ST)


  line3="%Cpu(s): $US us, $SY sy, $NI ni, $IDLE id, $WA wa, $HI hi, $SI si, $ST st"

  #make the fourth line of the header
  FREE=$(cat /proc/meminfo | grep MemFree | awk '{print $2}')
  let BUFF_CACHE=$(cat /proc/meminfo | grep Buffers | awk '{print $2}')
  for i in $(cat /proc/meminfo | grep Cached | awk '{print $2}')
  do
    let BUFF_CACHE=BUFF_CACHE+$i
  done

  let USED=TOTALMEM-FREE

  line4="KiB Mem : $TOTALMEM+total, $FREE+free, $USED+used, $BUFF_CACHE+buff/chache"
  
  #make the fifth line of the header

  TOTAL=$(cat /proc/meminfo | grep SwapTotal | awk '{print $2}')
  FREE=$(cat /proc/meminfo | grep SwapFree | awk '{print $2}')
  let USED=TOTAL-FREE
  AVAIL=$(cat /proc/meminfo | grep MemAvailable | awk '{print $2}')

  line5="KiB swap: $TOTAL+total, $FREE+free, $USED+used. $AVAIL+avail Mem"

  clear
  echo $line1"\n"$line2"\n"$line3"\n"$line4"\n"$line5
}

#This function calculates the CPU usage percentage given the clock ticks in the last $TIME_INTERVAL seconds
function jiffies_to_percentage () {
	
	#Get the function arguments (oldutime, oldstime, newutime, newstime)

	#Calculate the elpased ticks between newstime and oldstime (diff_stime), and newutime and oldutime (diff_utime)
  diff_stime=$news-$olds
  diff_utime=$newu-$oldu

	#You will use the following command to calculate the CPU usage percentage. $TIME_INTERVAL is the user-provided time_interval
	#Note how we are using the "bc" command to perform floating point division
  echo "100*( ($diff_stime + $diff_utime) / $hertz) / $timeInterval" | bc -l

}

#Generates the array of topN processes
function generate_top_report () {
    a=0
    num=$numProcesses

    #need to make sure there are enough processes to output, else output all processes
    exec 3>&2
    exec 2>/dev/null
    own=$(ls -al /proc | egrep $USER | wc -l)
    exec 2>&3
    if [ $all == 0 -a $num -gt $own ]; then
      num=$own
    fi


    #get num values
    while [ $a -lt $num ]
    do
      max=0
      b=0
      #iterate through list to extract the current highest usage depending on inour flag
      for id in ${cur_processes[@]}
      do
        if [ $measure == 0 ]; then
          if [ $(echo "${cpuUsage[$b]} > ${cpuUsage[$max]}" | bc -l) -gt 0 ]; then
            max=$b
          fi
        else
          exec 3>&2
          exec 2>/dev/null
          if [ $(echo "${memUsage[$b]} > ${memUsage[$max]}" | bc -l) -gt 0 ]; then
            max=$b
          fi
          exec 2>&3
        fi
        let b=b+1
      done

      #update appropriate arrays
      topNIndex[$a]=$max
      topCPUUsage[$a]=${cpuUsage[$max]}
      topMemUsage[$a]=${memUsage[$max]}
      memUsage[$max]=-100
      cpuUsage[$max]=-100
      let a=a+1
    done
}

#This function gets all the processes IDs depending on flag -a
function get_processes () {
  a=0
  if [ $all == 1 ]; then
    for id in $(ls /proc | egrep [0-9]+)
    do
      cur_processes[$a]=$id
      let a=a+1
    done
  else
    exec 3>&2
    exec 2>/dev/null

    for id in $(ls -al /proc | egrep $USER | awk '{print $9}')
    do
      cur_processes[$a]=$id
      let a=a+1
    done

    exec 2>&3
  fi
}

#Returns a percentage representing the CPU usage
function calculate_cpu_usage () {

	#CPU usage is measured over a periode of time. We will use the user-provided interval_time value to calculate 
	#the CPU usage for the last interval_time seconds. For example, if interval_time is 5 seconds, then, CPU usage
	#is measured over the last 5 seconds

#get old utime and stime
  a=0
  for i in ${cur_processes[@]}
  do
    #ensure the file exists
    if [ -f "/proc/$i/stat" ]; then
      #to check if the name is only length 1 as that impacts the $i values
      char=$(cat /proc/$i/stat | awk '{print $2}')
      if [[ $char == *")"* ]]; then
        oldutime[$a]=$(cat /proc/$i/stat | awk '{print $14}')
        oldstime[$a]=$(cat /proc/$i/stat | awk '{print $15}')
      else
        oldutime[$a]=$(cat /proc/$i/stat | awk '{print $15}')
        oldstime[$a]=$(cat /proc/$i/stat | awk '{print $16}')
      fi
    else
      #if file doesn't exist, set its usage to 0
      oldutime[$a]=0
      oldstime[$a]=0
    fi
    let a=a+1
  done

	#Sleep for time_interval
  sleep $timeInterval

	#Now, get the current utime and stime (newutime and newstime) /proc/{pid}/stat
  
  a=0
  for i in ${cur_processes[@]}
  do
    if [ -f "/proc/$i/stat" ]; then
      char=$(cat /proc/$i/stat | awk '{print $2}')
      if [[ $char == *")"* ]]; then
        newutime[$a]=$(cat /proc/$i/stat | awk '{print $14}')
        newstime[$a]=$(cat /proc/$i/stat | awk '{print $15}')
      else
        newutime[$a]=$(cat /proc/$i/stat | awk '{print $15}')
        newstime[$a]=$(cat /proc/$i/stat | awk '{print $16}')
      fi
      memUsage[$a]=$(cat /proc/$i/status | grep VmRSS | awk '{print $2}')
    else
      oldutime[$a]=0
      newutime[$a]=0
      oldstime[$a]=0
      newstime[$a]=0
      memUsage[$a]=0
    fi
    let a=a+1
  done

	#The values we got so far are all in jiffier (not Hertz), we need to convert them to percentages, we will use the function
	#jiffies_to_percentage

  a=0
  for i in ${cur_processes[@]}
  do
    #preparing to call the jiffies to percentage function
    #echo ${oldutime[$a]}
    olds=${oldstime[$a]}
    oldu=${oldutime[$a]}
    news=${newstime[$a]}
    newu=${newutime[$a]}
    cpuUsage[$a]=$(jiffies_to_percentage ${oldutime[$a]} ${oldstime[$a]} ${newutime[$a]} ${newstime[$a]})
    if [ $(echo "${cpuUsage[$a]} < 0" | bc -l) -gt 0 ]; then
      ${cpuUsage[$a]}=0
    fi
    let a=a+1
  done
}

check_arguments $# $@

#echo -e $line
#procmon runs forever or until ctrl-c is pressed.
while [ -n "$(ls /proc/$PID)" ] #While this process is alive
do
  get_processes
  calculate_cpu_usage
  h=$(header)
  generate_top_report

  #go through the topNindex array to generate the output line for each processes
  a=0
  report=""
  for i in ${topNIndex[@]}
  do
    ID=${cur_processes[$i]}

    #ensure the processes still exists
    if [ -d "/proc/$ID" ]; then
    #US is User, PR = prioirty, NI = Nice, Virt = Virtual mem, Res = usage, SHR = shared mem, S = state, CPU, RES extracted from top arrays, TIME = time spent on task i.e utime+stime, COMMAND = command name

    if [ $all == 1 ]; then
      #US=$(id -nu $(cat /proc/$ID/loginuid))
      exec 3>&2
      exec 2>/dev/null
      US=$(ls -al /proc/$ID | grep "stat" |awk '{print $3; exit}')
      exec 2>&3
    else
      US=$USER
    fi
    #checking for name length for appropirate positioning
    char=$(cat /proc/$ID/stat | awk '{print $2}')
    if [[ $char == *")"* ]]; then
      PR=$(cat /proc/$ID/stat | awk '{print $18}')
      NI=$(cat /proc/$ID/stat | awk '{print $19}')
      STATUS=$(cat /proc/$ID/stat | awk '{print $3}')
    else
      PR=$(cat /proc/$ID/stat | awk '{print $19}')
      NI=$(cat /proc/$ID/stat | awk '{print $20}')
      STATUS=$(cat /proc/$ID/stat | awk '{print $4}')
    fi
    #calculating time
    let TIME=${newutime[$i]}
    let TIME=TIME+${newstime[$i]}

    if [ $PR == -100 ]; then
      PR="rt"
    fi
    VIRT=$(cat /proc/$ID/status | grep VmSize | awk '{print $2}')
    #if processes doesn't have VIRT, it doesn't have RES, or RSS so need to set to 0
    if [ $VIRT ]; then
      RES=${topMemUsage[$a]}
      let SHR=$(cat /proc/$ID/status | grep RssFile | awk '{print $2}')+$(cat /proc/$ID/status | grep RssShmem | awk '{print $2}')
    else
      VIRT=0
      RES=0
      SHR=0
    fi
    MEM=$(bc -l <<< "100 * ($RES/$TOTALMEM)")
    CPU=${topCPUUsage[$a]}
    COMMAND=$(cat /proc/$ID/comm)

    #Format everything to the right length
    ID=$(printf "%6s" $ID)
    US=$(printf "%-9s" $US)
    PR=$(printf "%4d" $PR)
    NI=$(printf "%3d" $NI)
    VIRT=$(printf "%7s" $VIRT)
    RES=$(printf "%6s" $RES)
    SHR=$(printf "%6s" $SHR)
    CPU=$(printf "%.1f" $CPU)
    CPU=$(printf "%4s" "$CPU")
    MEM=$(printf "%.1f" $MEM)
    MEM=$(printf "%4s" "$MEM")


    #Format time
    UPTIME=$(printf "%.f" $TIME)
    PRINT_UPTIME=""
    #1 minute = 60 seconds
    let MINS=$((UPTIME/6000))
    PRINT_UPTIME=$PRINT_UPTIME$MINS":"
    let UPTIME=UPTIME-$(($MINS*6000))
    let SEC=$((UPTIME/100))
    PRINT_SEC=$SEC
    if [ $SEC -lt 10 ]; then
      PRINT_SEC="0"$SEC
    fi
    PRINT_UPTIME=$PRINT_UPTIME$PRINT_SEC"."
    let UPTIME=UPTIME-$(($SEC*100))
    if [ $UPTIME -lt 10 ]; then
      UPTIME="0"$UPTIME
    fi
    PRINT_UPTIME=$PRINT_UPTIME$UPTIME
    PRINT_UPTIME=$(printf "%9s" $PRINT_UPTIME)

    report="$report$ID $US$PR $NI $VIRT $RES $SHR $STATUS  $CPU $MEM $PRINT_UPTIME $COMMAND\n"
    fi
    let a=a+1
  done

  echo -e $h
  echo
  echo "   PID USER       PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND"
  echo -e "$report"
  #sleep 10
done
