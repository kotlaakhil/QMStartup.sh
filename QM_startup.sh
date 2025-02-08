#!/bin/bash
QUEUE_MANAGERS=("TESTMQ" "TESTMQ1")
LOG_FILE="pathfile/MQStartupscript/logfile.log"

declare -a SENDER_CHANNELS
SENDER_CHANNELS["TESTMQ"]="TESTMQ.TO.TESTMQ1"
SENDER_CHANNELS["TESTMQ1"]="TESTMQ.TO.TESTMQ"

#function to check the queue manager status 
check-qm-status() {
    QM_NAME="$1"
       echo "$(date): Checking the status of Queue Manager :$QM_NAME"  >> "$LOG_FILE"
    STATUS_OUTPUT=$(dspmq -m "$QM_NAME" 2>&1)
         echo "$(date): dspmq output: $STATUS_OUTPUT" >>"$LOG_FILE"

         echo "$STATUS_OUTPUT" | grep -i "RUNNING" >> "$LOG_FILE"
         return $?
}         
#Function to start the queue manager
START_QM() {
    QM_NAME="$1"
        echo "$(date): Attempting to start Queue manager $QM_NAME ---------" >> "$LOG_FILE"
        strmqm "$QM_NAME" >> $LOG_FILE 2>>$LOG_FILE

        if [ $? -eq o ]; then 
            echo "$(date) : Queue Manager $QM_NAME Started Successfully." >> "$LOG_FILE"
              return 0
        else
        echo "$(date): Failed to start queue manager $QM_NAME. check logs for error." >> "$LOG_FILE"
        return 1
    fi
}
#Function to check and update sender channel status
update_sender_channel_status() {
     QM_NAME="$1"
     CHANNELS="{$SENDER_CHANNELS[$QM_NAME]}"

     if [[ -z "$CHANNELS" ]]; then
        echo "$(date): No Sender channel defined for $QM_NAME. Skipping." >> "$LOG_FILE"
           return 0
     fi
         for  CHANNEL_NAME in $CHANNELS; do
         echo "$(date): checking sender channel $CHANNEL_NAME on $QM_NAME >> "$LOG_FILE"

         CHANNEL_STATUS=$(echo "DIS CHS('$CHANNEL_NAME')" | runmqsc "$QM_NAME" 2>&1)
                  echo "$(date): Channel status output: $CHANNEL_STATUS" >> "$LOG_FILE"
         echo "$CHANNEL_STATUS" | grep -q "RUNNING"
         if [$? -ne o ]; then 
               echo "$(date):Sender channel $CHANNEL_NAME is NOT running on $QM_NAME.Restarting....." >>"$LOG_FILE"
                              echo "STOP CHL('$CHANNEL_NAME') MODE(FORCE)" | runmqsc "$QM_NAME" >> "$LOG_FILE"
                              echo "RESET CHL('$CHANNEL_NAME') SEQNUM(1)" | runmqsc "$QM_NAME" >> "$LOG_FILE"
                              echo "START CHL('$CHANNEL_NAME')" | runmqsc "$QM_NAME" >> "$LOG_FILE"

         if [ $? -eq 0 ]; then
             echo "$(date): Sender Channel $CHANNEL_NAME Started Successfully on $QM_NAME." >> "LOG_FILE"
        else 
             echo "$(date): Failed to start Sender Channel $CHANNEL_NAME on $QM_NAME. Check MQ error logs." >> "$LOG_FILE"
        fi
     else
        echo "$(date): Sender channel $CHANNEL_NAME is already running on $QM_NAME." >> "$LOG_FILE"
        fi
  done
}

#Loop all Queue Managers and start
for qm_name in "${QUEUE_MANAGERS[@]}"; do 
    echo "$(date): Processing queue manager: $qm_name" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"
      check_qm_status "qm_name"
      if [ $? -ne 0 ] ; then
         START_QM "$qm_name"
      fi
echo "--------------------------------------" >>"$LOG_FILE"
      check_qm_status "$qm_name"
      EXIT_STATUS="$?"
      if [ $EXIT_STATUS -eq 0 ]; then 
           update_sender_channel_status "$qm_name"
      else
                echo "----  $EXIT_STATUS"
      echo "$(date): Queue Manager $qm_name  Failed to start. Skipping channel updates."  >> "$LOG_FILE"
      fi
done
exit 0
        
