#!/bin/bash


tail -Fn0 /var/log/nagios/nagios.log | \
while read line ; do
        echo "$line" | grep -e "SERVICE NOTIFICATION"
        if [ $? = 0 ]
        then

                echo $line >> /mnt/nagios_log_chk/critical.log
                hostname=$(echo $line | cut -d ":" -f 2 | cut -d ";" -f 2)
                address=$(grep $hostname /mnt/nagios_log_chk/host_name.csv | cut -d " " -f 2)
                #contact=$(grep $hostname /mnt/nagios_log_chk/host_name.csv | cut -d " " -f 3)
                contact=$(echo "Operations")
                issue_status=$(echo $line | cut -d ";" -f4)
                issue=$(echo $line | cut -d ";" -f 3-4)
                description=$(echo $line | cut -d ";" -f 3,4,6-)
                jira_project_key=$(grep $contact /mnt/nagios_log_chk/jira_details.csv | cut -d " " -f 2)
                jira_project_id=$(grep $contact /mnt/nagios_log_chk/jira_details.csv | cut -d " " -f 3)

                MYT=$(TZ=Asia/Kuala_Lumpur date)

                last_issue_line=$(grep -e "SERVICE NOTIFICATION.*$hostname" /mnt/nagios_log_chk/critical.log | tail -3 | grep -v "last issue line" | head -1)
                last_status=$(echo $last_issue_line |  cut -d ";" -f 4)

                if [ "$issue_status" == "CRITICAL" ]
                then
                        issue_type="Incident"
                elif [ "$issue_status" == "OK" ]
                then
                        if [ "$last_status" == "CRITICAL" ]
                        then
                                issue_type="Incident"
                        else
                                issue_type="MS Alert"
                        fi
                else
                        issue_type="MS Alert"
                fi

                echo -e "time: $MYT\n hostname : $hostname\n address : $address\n issue : $issue\n description : $description\n \
contact group : $contact\n project key : $jira_project_key\n project id : $jira_project_id \n issue_status : $issue_status\n last issue line : $last_issue_line\n last status : $last_status" >> /mnt/nagios_log_chk/critical.log

                TICKET_URL="https://boost-holdings.atlassian.net/rest/api/2/issue"
                ACCESS_TOKEN="c2lkYXRoQG15Ym9vc3QuY286QVRBVFQzeEZmR0YwSVhwb18wSzNoR3RwS2ExcmtyRmotN1BLeExQT3o3aVJnYVRZUWZyU2JqVzVpb1dsQnpLbi1JX1VrWGJkdzRuUFFrNkRBNFdza0F6dVZ6bm1Ib0N6a01xVEJUWlE3MzJmQzhHdUJoSGg0Y09Sb09wd2VZZ25QWk9yNVp2N2lWY3NSQzFzQnJVdVJTWDRWS09admFqc3VTY1p5a2Z3QkxPTVZqcGpMSGxFUTk4PUM1OEFCQTNB"



                ticket_status=$(curl "$TICKET_URL" \
                -H "Authorization: Basic $ACCESS_TOKEN" \
                -H "Content-Type:application/json" \
                --data @-  << EOF
                            {
                             "update": {
                              },
                             "fields": {
                             "project": { "id": "$jira_project_id" },
                             "issuetype": { "name": "$issue_type" },
                             "priority": { "name": "High" },
                             "summary": "Nagios Notication $hostname   - $issue",
                             "description": "Nagios Notification:\n\n Host: $hostname  \n\n $description \n\n time: $MYT\n "

                          }
                }
EOF)

                echo "jira ticket: $ticket_status\n" >> /mnt/nagios_log_chk/critical.log
        fi
done
