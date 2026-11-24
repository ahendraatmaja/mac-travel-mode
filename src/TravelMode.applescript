-- Travel Mode: shows awake state, Wi-Fi (iPhone hotspot or not) and battery, and flips the state with one button.
set tm to quoted form of ((POSIX path of (path to me)) & "Contents/Resources/bin/travel-mode")

repeat
	set isOn to (do shell script tm & " is-on && echo yes || echo no") is "yes"
	set batt to do shell script "/usr/bin/pmset -g batt | /usr/bin/grep -Eo '[0-9]+%' | /usr/bin/head -1"
	set wifiRaw to do shell script tm & " wifi"
	set AppleScript's text item delimiters to tab
	set wifiState to text item 1 of wifiRaw
	set wifiMsg to text item 2 of wifiRaw
	set AppleScript's text item delimiters to ""
	set onHotspot to (wifiState is "hotspot")
	set hotspotName to do shell script tm & " hotspot || true"
	if hotspotName is "" then
		set joinLabel to "Join Hotspot"
	else
		set joinLabel to "Join " & hotspotName
	end if
	set info to "Wi-Fi: " & wifiMsg & return & "Battery: " & batt

	if isOn then
		set msg to "Travel Mode is ON" & return & return & "Your Mac stays awake with the lid closed, locks when you close it, and rejoins your hotspot if Wi-Fi drops." & return & return & info
		if onHotspot then
			set r to display dialog msg buttons {"Keep On", "Turn Off"} default button "Keep On" with title "Travel Mode" with icon note
		else
			set r to display dialog msg buttons {joinLabel, "Keep On", "Turn Off"} default button joinLabel with title "Travel Mode" with icon caution
		end if
	else
		set msg to "Travel Mode is OFF" & return & return & "Turn it on to keep your Mac awake with the lid closed. The screen still locks when you close it, and it rejoins your hotspot if Wi-Fi drops." & return & return & info
		if onHotspot then
			set r to display dialog msg buttons {"Cancel", "Turn On"} default button "Turn On" with title "Travel Mode" with icon note
		else
			set r to display dialog msg buttons {"Cancel", joinLabel, "Turn On"} default button "Turn On" with title "Travel Mode" with icon note
		end if
	end if
	set b to button returned of r

	if b is joinLabel then
		if hotspotName is "" then
			set nets to paragraphs of (do shell script tm & " networks")
			set picked to choose from list nets with title "Travel Mode" with prompt "Which saved network is your iPhone hotspot?"
			if picked is not false then
				set hotspotName to item 1 of picked
				do shell script tm & " hotspot " & quoted form of hotspotName
			end if
		end if
		if hotspotName is not "" then
			try
				do shell script tm & " join"
				display notification "Connected to " & hotspotName & "." with title "Travel Mode"
			on error
				display dialog "Couldn't join " & hotspotName & "." & return & return & "On your iPhone, open Settings > Personal Hotspot and keep that screen open, or pick " & hotspotName & " from the Wi-Fi menu at the top of the screen. Then try again." buttons {"OK"} default button "OK" with title "Travel Mode" with icon caution
			end try
		end if
		-- loop: show the updated status
	else if b is "Turn Off" then
		try
			do shell script tm & " off"
			display notification "Normal sleep is back." with title "Travel Mode is off"
		on error
			display notification "Nothing changed." with title "Travel Mode is still on"
		end try
		exit repeat
	else if b is "Turn On" then
		try
			do shell script tm & " on"
			display notification "Wi-Fi: " & wifiMsg with title "Travel Mode is on"
		on error
			display notification "Nothing changed." with title "Travel Mode is still off"
		end try
		exit repeat
	else
		exit repeat
	end if
end repeat
