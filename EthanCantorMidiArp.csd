<CsoundSynthesizer>
    <CsOptions>
        /**
            Ethan Cantor
            Live MIDI arpeggiator

            This is a program written in CSound that uses a MIDI keyboard to generate arpeggiated notes of various timbres when multiple keys are pressed. 
            It also includes a drum machine with drum sounds created from noise. 
            
        */
        -+rtmidi=portmidi -Ma -odac0
    </CsOptions>
    
    <CsInstruments>
        sr = 48000
        ksmps = 32
        nchnls = 2
        0dbfs = 1

        massign 0, 0    ; disable all midi channels per instrument except:
        ; massign 1, "triggerInst"    

        /**
            Arrays that hold the entire MIDI protocol information. The Data1 is stored as the placement of each array. This
            is done because Data1 is the MIDI note number AKA what key you pressed.
        */
        gkStatusArray[] init 128
        gkChanArray[] init 128
        gkData2Array[] init 128

        gkNumElements init 1        ; k rate variable to keep up to date how many keys are currently being held down
        gkNoteLength init 1         ; k rate variable to store the current length of each note AKA how long each repeat is in the ARP.
                                    ; This is changed using the MOD wheel (MIDI 1)

        gkTune init 0               ; controls overall tuning of the keyboard 
        gkDrumSelect init 0         ; controls which drum pattern
        gkWaveSelect init 1         ; controls which wave is playing

        /**
            instruments include:
            * sawcilator (saw oscilator)
            * drumBody
            * transient
            * kickDrum
            * snareDrum
            * hatDrum
        */                            
        #include "SoundInstruments.csd"     
        
        /**
            2D arrays for the drum machine
         */
        #include "DrumMachineArrays.csd"

        /**
            MODULATION CONTROL SECTION. 
            These global variables need to be changed based on what midi channels you want to control
            each of the modulations.
        */
		giMOD0 = 1
        giMOD1 = 14
        giMOD2 = 15
        giMOD3 = 16
        prints "giMOD0 ARP SPEED: %d\n", giMOD0
        prints "giMOD1 TUNE: %d\n", giMOD1
        prints "giMOD2 DRUM PATTERN: %d\n", giMOD2
        prints "giMOD3 ARP WAVE: %d\n", giMOD3

        /**
            Main juice of the entire program. It uses timout opcode to create a clock that steps through an array of all the current notes being 
            held down. 

            THINGS THAT I TRIED TO MAKE WORK BUT DIDN'T:
                * changing the size of the array and only including notes that are currently being held down
                * stepping through the array faster when there is no note to be played and playing the notes at normal time

            INPUTS:
            p2: iStart: start of the arpegiator 
            p3: iLength: how long the arpegiator runs
            p4: iNoteLengthInit: initial length of the notes as well as the loops
            p5: iDrumAmp: loudness of the drums
        */
        instr arpegiator
            iStart init p2
            iLength init p3
            iNoteLengthInit init p4
            iDrumAmp init p5

            ; set the initial note length to whatever is fed in through p fields
            iNoteLength init iNoteLengthInit 

            ; start the arp at the bottom
            iCurrentSelect init 0

            ; drum patter stuff initializing the drums to be a blank pattern and
            ; start them at the first drum 
            iCurrentPattern[][] = giDrumPattern0
            iLastPattern[][] = giDrumPattern0
            iCurrentDrum init 0 

            /**
                ===================== LOOP SECTION ============================
                Main loop of the entire instrument. The drum machine and the 
                arp are together in this section
            */
            clock:          
                timout 0, iNoteLength, arp
                reinit clock

                iNoteLength = i(gkNoteLength) * iNoteLengthInit                
                kStatus = gkStatusArray[iCurrentSelect]
                kChan = gkChanArray[iCurrentSelect]
                kData2 = gkData2Array[iCurrentSelect]

                kI init 0
                kJ init 0
                kCurrentAmpArray[] init i(gkNumElements)
                kCurrentNoteArray[] init i(gkNumElements)
                while kI < 128 do
                    if gkStatusArray[kI] == 144 then
                        kCurrentAmpArray[kJ] = gkData2Array[kI]
                        kCurrentNoteArray[kJ] = kI
                        kJ += 1
                    endif
                    kI += 1
                od

            ; ================== SECOND PART OF LOOP =======================
            arp:
            
                ; ================= BASIC ARP STEPPING ALGORITHM ================
                ; Up all the way then back to the start
                ; skip if current element is 0 but 0 is always last so we want current select to never select 0
                iCurrentSelect  += 1
                if (iCurrentSelect > i(gkNumElements) - 1 && i(gkNumElements) - 1 > 0) then
                    iCurrentSelect = 1
                elseif (iCurrentSelect > i(gkNumElements) - 1 && i(gkNumElements) - 1 <= 0) then
                    iCurrentSelect = 0
                endif

                ; get the amp and note for the current note to play
                kCurrentAmp = kCurrentAmpArray[iCurrentSelect - 1]
                kCurrentNote = kCurrentNoteArray[iCurrentSelect - 1]
                
                ; update the note length based on the multipler from the MOD0 which by default is the modwheel
                iNoteLength = i(gkNoteLength) * iNoteLengthInit 
                
                ; play the note only if there is a note to play. Reason for - 1 is because there always needs to be at least one note in 
                ; the array so the first one is just a null thing. csound hate blank arrays
                if(i(gkNumElements) - 1 > 0) then
                    schedule "sawcilator", 0, iNoteLength - 0.01, kCurrentNote, kCurrentAmp, gkTune
                endif

                /** ================ DRUM MACHINE ======================      
                    I moved the drum machine into this loop so that it would be in sync with the arp
                    rather than have it in another file and another loop
                */
                iLastPattern[][] = iCurrentPattern

                if(i(gkDrumSelect) == 0) then
                    iCurrentPattern = giDrumPattern0
                elseif(i(gkDrumSelect) == 1) then
                    iCurrentPattern = giDrumPattern1
                elseif(i(gkDrumSelect) == 2) then
                    iCurrentPattern = giDrumPattern2
                elseif (i(gkDrumSelect) == 3) then
                    iCurrentPattern = giDrumPattern3
                elseif (i(gkDrumSelect) == 4) then
                    iCurrentPattern = giDrumPattern4
                endif 

                iNumLast lenarray iLastPattern, 2
                iNumNotes lenarray iCurrentPattern, 2

                /**
                    this is to check if the current pattern has changed so it doesn't run over.
                */
                if(iNumLast != iNumNotes) then
                    iCurrentDrum = 0
                endif   
                        
                if(iCurrentPattern[0][iCurrentDrum] == 1) then    ; kick
                    schedule "kickDrum", 0, iNoteLength, iDrumAmp
                endif

                if(iCurrentPattern[1][iCurrentDrum] == 1) then    ; snare
                    schedule "snareDrum", 0, iNoteLength, iDrumAmp
                endif

                if(iCurrentPattern[2][iCurrentDrum] == 1) then    ; hat
                    schedule "hatDrum", 0, iNoteLength, iDrumAmp
                endif

                iCurrentDrum += 1
                if(iCurrentDrum > iNumNotes - 1) then
                    iCurrentDrum = 0
                endif
        endin

        /** =============================== TRIGGER INSTRUMENT =============================================
            This is the instrument that is triggered everytime a midi input from a keyboard or midi controller. 
         */
        instr triggerInst
            kStatus, kChan, kData1, kData2 midiin               ; recieve midi all of the midi information.

            kSTrigger changed kStatus                           ; these triggers are for checking if any of the midi information 
            kCTrigger changed kChan                             ; changed. It is useful so that the if statements and such dont 
            kD1Trigger changed kData1                           ; get checked all the time and such
            kD2Trigger changed kData2

            if kSTrigger == 1 || kCTrigger == 1 || kD1Trigger == 1 || kD2Trigger == 1 then      ; check to see if any of the triggers have popped
                if(kStatus == 144 || kStatus == 128) then                                       ; check for midi on (144) or midi off (128) statuses 
                    if(kStatus == 144) then                                                     ; these would imply a keyboard press or release
                        gkNumElements += 1
                    else 
                        if gkNumElements > 1 then              ; fix edge case of holding down a key before the program starts then releasing afterward
                            gkNumElements -= 1
                        endif
                    endif         
                    gkStatusArray[kData1] = kStatus
                    gkChanArray[kData1] = kChan
                    gkData2Array[kData1] = kData2
                endif

                if(kData1 == giMOD0) then    ; mod wheel    
                    gkNoteLength = 1 / ( 2 * (kData2 / 127) + 1)
                endif

                if(kData1 == giMOD1) then   ; TUNE KNOB
                    gkTune = kData2 + 1
                endif

                if(kData1 == giMOD2) then       ; DRUM PATTERN SELECT KNOB
                    gkDrumSelect = round((kData2 / 128) * (giNumDrumPatterns - 1))              ; this is a fun little rounding algorithm i thought up
                endif                                                                           ; that splits the entire knob into equal parts around the
                                                                                                ; number of selections (in this case drum patterns). 
                if(kData1 == giMOD3) then           ; WAVE SELECTOR KNOB
                    gkWaveSelect = round((kData2 / 128) * (giNumWaves - 1)) + 1
                endif
           endif
        endin

    </CsInstruments>
    
    <CsScore>
    ;   i instName      start   end     initNoteLen drumAmp
        i "arpegiator"  0       3600    0.5         0.5
        i "triggerInst" 0       3600
    </CsScore>
</CsoundSynthesizer>